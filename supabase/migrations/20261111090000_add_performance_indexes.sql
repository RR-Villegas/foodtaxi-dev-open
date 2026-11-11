-- Query-path indexes for the product/search and common account/order lookups.
-- These are safe, additive indexes and can be applied without changing API behavior.
create index if not exists idx_product_active_id
  on public.product (is_active, product_id desc);
create index if not exists idx_product_active_category
  on public.product (is_active, category);
create index if not exists idx_product_active_price
  on public.product (is_active, price);
create index if not exists idx_product_store_active
  on public.product (store_id, is_active);
create index if not exists idx_address_account_default_created
  on public.address (account_id, is_default desc, created_at desc);
create index if not exists idx_orders_buyer_status_created
  on public.orders (buyer_account_id, order_status, created_at desc);
create index if not exists idx_orders_rider_status_created
  on public.orders (rider_account_id, order_status, created_at desc);
create index if not exists idx_product_review_product
  on public.product_review (product_id);
