create extension if not exists "pgcrypto";

create table if not exists licenses (
  id          uuid primary key default gen_random_uuid(),
  key         text unique not null,
  serial      text not null,
  product     text default 'nusa-kasir',
  status      text default 'issued',   -- issued | activated | revoked
  owner_email text,
  created_at  timestamptz default now()
);

create table if not exists activations (
  id         uuid primary key default gen_random_uuid(),
  license_id uuid references licenses(id) on delete cascade,
  device_id  text not null,
  created_at timestamptz default now(),
  unique (license_id, device_id)
);

create index if not exists idx_licenses_key on licenses(key);
create index if not exists idx_activations_license on activations(license_id);

create or replace function can_activate(lid uuid)
returns boolean language sql stable as $$
  select count(*) < 2 from activations where license_id = lid;
$$;

-- RLS: Edge Function uses service role; no anon direct access needed.
