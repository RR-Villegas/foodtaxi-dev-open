begin;

create or replace function public.admin_get_audit_events(
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  event_id bigint,
  occurred_at timestamptz,
  actor_id uuid,
  table_schema text,
  table_name text,
  operation text,
  row_primary_key jsonb
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, audit
as $function$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.account
    where auth_id = auth.uid()
      and lower(account_type) = 'admin'
  ) then
    raise exception 'Administrator access required'
      using errcode = '42501';
  end if;

  return query
  select
    events.event_id,
    events.occurred_at,
    events.actor_id,
    events.table_schema,
    events.table_name,
    events.operation,
    events.row_primary_key
  from audit.events as events
  order by events.occurred_at desc, events.event_id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

revoke all on function public.admin_get_audit_events(integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_get_audit_events(integer, integer)
  to authenticated;

commit;
