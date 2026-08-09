-- ============================================================================
-- NUSA — Multi-App Ecosystem + Tier Pricing Migration
-- ============================================================================
-- 1. Add tier column (trial=3hari, 1month=1bulan, lifetime=selamanya)
-- 2. Update can_activate() — allow multi-product per Google account
-- 3. Convert existing trials from 30-day to 3-day
-- ============================================================================

-- 1. Add tier column
alter table licenses add column if not exists tier text default 'lifetime';
alter table licenses add constraint licenses_tier_check
  check (tier in ('trial', '1month', 'lifetime'));

-- 2. Convert existing Trial licenses to 3-day (from original 30-day)
--    Set expires_at to 3 days from creation for existing trials without explicit expiry
update licenses
set expires_at = created_at + interval '3 days'
where status = 'Trial'
  and (expires_at is null or expires_at > created_at + interval '4 days');

-- 3. Update can_activate() — multi-product support
--    Key change: Google account CAN have multiple licenses if they're different products
--    But CANNOT have multiple licenses for the SAME product
create or replace function can_activate(lid uuid, gid text)
returns boolean language plpgsql as $$
declare
  lic_status text;
  lic_expires timestamptz;
  lic_owner text;
  lic_product text;
  existing_count integer;
begin
  select status, expires_at, google_user_id, product
  into lic_status, lic_expires, lic_owner, lic_product
  from licenses where id = lid;

  if not found then
    return false;
  end if;

  -- Block Cancelled
  if lic_status = 'Cancelled' then
    return false;
  end if;

  -- Block Suspended
  if lic_status = 'Suspended' then
    return false;
  end if;

  -- Block Expired (expires_at set and passed)
  if lic_expires is not null and lic_expires < now() then
    return false;
  end if;

  -- Same Google account → allow (multi-device for same license)
  if lic_owner is not null and lic_owner = gid then
    return true;
  end if;

  -- Different Google account already owns this license → deny
  if lic_owner is not null and lic_owner != gid then
    return false;
  end if;

  -- NEW: Check if this Google account already has an active license for the SAME product
  -- Allows different products per Google account (e.g. Kelontong + F&B)
  select count(*) into existing_count
  from licenses
  where google_user_id = gid
    and id != lid
    and product = lic_product
    and (expires_at is null or expires_at >= now())
    and status not in ('Cancelled', 'Suspended', 'Expired');

  if existing_count > 0 then
    return false;
  end if;

  return true;
end;
$$;
