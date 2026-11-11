begin;

create schema if not exists audit;

create table if not exists audit.events (
  event_id bigint generated always as identity primary key,
  occurred_at timestamptz not null default clock_timestamp(),
  actor_id uuid,
  table_schema text not null,
  table_name text not null,
  operation text not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
  row_primary_key jsonb not null
);

create index if not exists audit_events_occurred_at_idx
  on audit.events (occurred_at desc);

alter table audit.events enable row level security;
revoke all on schema audit from public, anon, authenticated, service_role;
revoke all on all tables in schema audit from public, anon, authenticated, service_role;
revoke all on all sequences in schema audit from public, anon, authenticated, service_role;

create or replace function audit.capture_public_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, audit
as $function$
declare
  row_data jsonb;
  primary_key_data jsonb;
begin
  if tg_op = 'UPDATE' and old is not distinct from new then
    return new;
  end if;

  if tg_op = 'DELETE' then
    row_data := pg_catalog.to_jsonb(old);
  else
    row_data := pg_catalog.to_jsonb(new);
  end if;

  select pg_catalog.jsonb_object_agg(
    attribute.attname::text,
    row_data -> attribute.attname::text
  )
  into primary_key_data
  from pg_catalog.pg_index as index_info
  join pg_catalog.pg_attribute as attribute
    on attribute.attrelid = index_info.indrelid
    and attribute.attnum = any(index_info.indkey)
  where index_info.indrelid = tg_relid
    and index_info.indisprimary
    and not attribute.attisdropped;

  insert into audit.events (
    actor_id,
    table_schema,
    table_name,
    operation,
    row_primary_key
  )
  values (
    auth.uid(),
    tg_table_schema,
    tg_table_name,
    tg_op,
    coalesce(primary_key_data, '{}'::jsonb)
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

revoke all on function audit.capture_public_change()
  from public;
grant execute on function audit.capture_public_change()
  to anon, authenticated, service_role;

do $migration$
declare
  target_table text;
  target_tables constant text[] := array[
    'account',
    'account_verification',
    'address',
    'buyer_report',
    'discount_coupon',
    'market_flag',
    'order_items',
    'orders',
    'product',
    'product_discount',
    'product_report',
    'product_review',
    'product_variant',
    'rider_application',
    'rider_review',
    'seller_application',
    'seller_enforcement_action',
    'store',
    'store_report',
    'store_review'
  ];
begin
  foreach target_table in array target_tables loop
    if not exists (
      select 1
      from pg_catalog.pg_trigger as existing_trigger
      where existing_trigger.tgrelid =
          pg_catalog.to_regclass(pg_catalog.format('public.%I', target_table))
        and existing_trigger.tgname = 'audit_capture_public_changes'
        and not existing_trigger.tgisinternal
    ) then
      execute pg_catalog.format(
        'create trigger audit_capture_public_changes after insert or update or delete on public.%I for each row execute function audit.capture_public_change()',
        target_table
      );
    end if;
  end loop;
end;
$migration$;

commit;
