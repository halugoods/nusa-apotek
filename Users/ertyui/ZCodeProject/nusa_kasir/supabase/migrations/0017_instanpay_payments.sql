-- ============================================================================
-- NUSA — InstanPay: ensure payments cols + reload PostgREST schema cache
-- ============================================================================
-- Run this in Supabase Dashboard → SQL Editor.
-- Gagasan: tabel `payments` dibuat ad-hoc dulu (tanpa kolom L4). Kolom
-- `provider`, `snap_token`, `license_key`, `updated_at` dipakai oleh edge
-- function midtrans/instanpay. Beberapa belum ada di DB remote → insert
-- payments gagal diam-diam (also midtrans!). Perbaiki sekali sekalian lalu
-- reload schema cache PostgREST supaya layar ke edge function.
-- ============================================================================

alter table payments add column if not exists snap_token   text;
alter table payments add column if not exists license_key  text;
alter table payments add column if not exists provider     text default 'midtrans';
alter table payments add column if not exists updated_at   timestamptz default now();

-- Ensure licenses has the owner_email column used at license insert
alter table licenses add column if not exists owner_email  text;

-- Reload PostgREST schema cache so the new columns are visible to edge functions
notify pgrst, 'reload schema';