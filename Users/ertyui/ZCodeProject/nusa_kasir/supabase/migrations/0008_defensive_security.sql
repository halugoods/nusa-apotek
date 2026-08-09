-- Defensive security hardening. Apply after 0007.
-- Existing clients must authenticate before calling protected Edge Functions.

begin;

-- Tenant ownership is explicit for the online-store service.
alter table if exists store_settings add column if not exists owner_user_id uuid references auth.users(id) on delete set null;
create index if not exists idx_store_settings_owner on store_settings(owner_user_id);

alter table if exists store_settings enable row level security;
alter table if exists online_products enable row level security;
alter table if exists online_orders enable row level security;
alter table if exists licenses enable row level security;
alter table if exists activations enable row level security;

-- Public storefront reads are deliberately limited to active/published rows.
-- Remove the legacy order policies that allowed arbitrary cross-tenant reads/writes.
drop policy if exists "Public can insert orders" on online_orders;
drop policy if exists "Public can read own orders" on online_orders;
drop policy if exists "Public can read active stores" on store_settings;
create policy "Public can read active stores" on store_settings for select to anon, authenticated using (is_active = true);
drop policy if exists "Public can read published products" on online_products;
create policy "Public can read published products" on online_products for select to anon, authenticated using (is_published = true);

-- Store owners manage only their own account path. Edge Function verifies the same path.
drop policy if exists "Store owners manage own settings" on store_settings;
create policy "Store owners manage own settings" on store_settings for all to authenticated
  using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
drop policy if exists "Store owners manage own products" on online_products;
create policy "Store owners manage own products" on online_products for all to authenticated
  using (exists (select 1 from store_settings s where s.store_id = online_products.store_id and s.owner_user_id = auth.uid()))
  with check (exists (select 1 from store_settings s where s.store_id = online_products.store_id and s.owner_user_id = auth.uid()));
drop policy if exists "Store owners manage own orders" on online_orders;
create policy "Store owners manage own orders" on online_orders for all to authenticated
  using (exists (select 1 from store_settings s where s.store_id = online_orders.store_id and s.owner_user_id = auth.uid()))
  with check (exists (select 1 from store_settings s where s.store_id = online_orders.store_id and s.owner_user_id = auth.uid()));

-- Do not expose license inventory or activation records through the client API.
drop policy if exists "Public can read licenses" on licenses;
drop policy if exists "Public can read activations" on activations;

-- Backups are private and strictly scoped to {auth.uid}/... paths.
drop policy if exists "nusa_backups_insert" on storage.objects;
drop policy if exists "nusa_backups_select" on storage.objects;
drop policy if exists "nusa_backups_update" on storage.objects;
drop policy if exists "nusa_backups_delete" on storage.objects;
create policy "nusa_backups_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'nusa-backups' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "nusa_backups_select" on storage.objects for select to authenticated
  using (bucket_id = 'nusa-backups' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "nusa_backups_update" on storage.objects for update to authenticated
  using (bucket_id = 'nusa-backups' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'nusa-backups' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "nusa_backups_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'nusa-backups' and (storage.foldername(name))[1] = auth.uid()::text);

-- Images remain publicly readable by design, but writes require the owner's path.
-- The bucket itself must remain public for storefront image URLs.

commit;
