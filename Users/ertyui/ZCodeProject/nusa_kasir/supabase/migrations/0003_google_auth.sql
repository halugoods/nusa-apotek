-- ============================================================================
-- NUSA KASIR — Migration 0003: Google Auth overhaul
-- ============================================================================
-- Replaces device-based activation with Google-ID-based activation:
--   - licenses.google_user_id: links a license to one Google account
--   - activations.google_user_id: tracks which Google account activated
--   - can_activate(): now checks google_user_id uniqueness instead of device count
--   - No more 2-device limit — 1 Google account = unlimited devices
--
-- NOTE: Must be run via `supabase db push` or manually in SQL editor.
-- ============================================================================

begin;

-- 1. Add google_user_id to licenses (nullable — filled on activation)
alter table licenses
  add column if not exists google_user_id text;

create index if not exists idx_licenses_google_user_id
  on licenses(google_user_id);

-- 2. Add google_user_id to activations
alter table activations
  add column if not exists google_user_id text;

-- 3. Add unique constraint: one Google ID per license
--    (If a Google ID already has a different license, they need to use the same one)
alter table activations
  drop constraint if exists activations_license_device_unique;

-- Add constraint: a Google ID can only activate one license row
-- (but may create multiple activations across devices for the same license)
-- We keep license_id + device_id unique constraint for backward compat
-- (device_id is now nullable but kept for tracking)
alter table activations
  add constraint activations_license_device_unique
  unique (license_id, device_id);

-- 4. Drop old can_activate (device count based)
drop function if exists can_activate(uuid);

-- 5. New can_activate: one Google ID cannot activate multiple different licenses
--    but can activate the same license on multiple devices.
create or replace function can_activate(
  lid uuid,
  gid text
)
returns boolean
language plpgsql
as $$
begin
  -- If this exact license already has this google_user_id, allow (multi-device)
  if exists (
    select 1 from licenses
    where id = lid
      and google_user_id = gid
  ) then
    return true;
  end if;

  -- If this license already has a different google_user_id, deny
  if exists (
    select 1 from licenses
    where id = lid
      and google_user_id is not null
      and google_user_id != gid
  ) then
    return false;
  end if;

  -- If this Google ID already has a DIFFERENT license, deny
  -- (one Google account = one license)
  if exists (
    select 1 from licenses
    where google_user_id = gid
      and id != lid
  ) then
    return false;
  end if;

  -- Otherwise, allow
  return true;
end;
$$;

commit;
