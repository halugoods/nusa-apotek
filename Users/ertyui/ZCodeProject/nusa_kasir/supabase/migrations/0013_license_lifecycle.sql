-- ============================================================================
-- NUSA — License Lifecycle Migration (v2.2.44 Batch 2: L1)
-- ============================================================================
-- 1. Add order_id to licenses (for payment linkage — midtrans writes it,
--    verify() reads it back to avoid duplicate keys)
-- 2. Add expires_at to licenses (trial/1month expiry + grace tracking)
-- 3. Backfill expires_at for already-active 1month/trial licenses (from
--    payments.package when available; fallback 30/3 days from created_at)
-- 4. Add tier column if missing (some midtrans inserts omit tier)
-- 5. Add payment gateway abstraction columns (provider/payment_url) so app
--    only opens /pay — gateway swap never touches the app (L4)
-- 6. Add license_events table for the auto-revoke audit trail (L1)
-- ============================================================================

-- 1. order_id on licenses (payment linkage)
alter table licenses add column if not exists order_id text;

-- 1b. payments table (midtrans/get_token writes it, verify() reads it) —
-- DDL sebelumnya dibuat ad-hoc di Supabase tanpa migration; sekarang diformalkan
-- supaya cron + backfill bisa diandalkan di semua environment.
create table if not exists payments (
  id          uuid primary key default gen_random_uuid(),
  order_id    text not null unique,
  google_id   text not null,
  product     text default 'nusa-kasir',
  package     text,                 -- '1bulan' | 'lifetime'
  amount      numeric not null default 0,
  status      text default 'pending', -- pending | settlement | capture | expired | ...
  snap_token  text,
  license_key text,
  provider    text default 'midtrans', -- L4: gateway abstraction
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
create index if not exists idx_payments_google on payments(google_id);
create index if not exists idx_payments_order on payments(order_id);

-- 2. expires_at on licenses
alter table licenses add column if not exists expires_at timestamptz;

-- 3. tier (midtrans inserts sometimes omit it — DB default is 'lifetime' wrong)
alter table licenses add column if not exists tier text default 'lifetime';
alter table licenses drop constraint if exists licenses_tier_check;
alter table licenses add constraint licenses_tier_check
  check (tier in ('trial', '1month', 'lifetime'));

-- 4. payment gateway abstraction (L4) — app opens /pay, gateway is pluggable
alter table licenses add column if not exists payment_provider text default 'midtrans';
alter table licenses add column if not exists payment_url text;

-- Backfill expires_at for active non-lifetime licenses that have none yet.
-- Source of truth first: payments.package; fallback by tier.
update licenses l
set expires_at = coalesce(
  (select p.created_at + interval '30 days'
     from payments p
    where p.order_id = l.order_id and p.package = '1bulan'),
  (select p.created_at + interval '36500 days'
     from payments p
    where p.order_id = l.order_id and p.package = 'lifetime'),
  case
    when l.tier = '1month' then l.created_at + interval '30 days'
    when l.tier = 'trial'  then l.created_at + interval '3 days'
    else l.expires_at
  end
)
where l.expires_at is null
  and l.status in ('Active', 'Trial')
  and (l.tier in ('1month', 'trial') or l.order_id is not null);

-- 5. license_events — audit trail for auto-revoke cron (L1)
create table if not exists license_events (
  id         uuid primary key default gen_random_uuid(),
  license_id uuid references licenses(id) on delete cascade,
  event      text not null,           -- 'expired' | 'revoked' | 'grace_started' | 'renewed'
  detail     text,
  created_at timestamptz default now()
);
create index if not exists idx_license_events_license
  on license_events(license_id);
create index if not exists idx_license_events_created
  on license_events(created_at);

-- 6. Cron worker runs with service role; ensure RLS does not block it.
alter table license_events enable row level security;
create policy "service_role_all_license_events"
  on license_events for all
  to service_role using (true) with check (true);
