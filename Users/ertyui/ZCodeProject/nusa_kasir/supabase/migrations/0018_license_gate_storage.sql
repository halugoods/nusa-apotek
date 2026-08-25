-- ============================================================================
-- 0018 — License-gated cloud backup access (v2.2.53 fix)
-- ============================================================================
-- MASALAH: lisensi yang di-cancel/revoke masih bisa dipakai masuk app dan
-- sync/restore data cloud. App yang sudah aktivasi tidak lewat layar aktivasi
-- lagi saat startup (langsung /login atau /home), jadi satu-satunya gate
-- server-side yang menyentuh app tiap sesi adalah Supabase Storage backup.
--
-- FIX: akses bucket `nusa-backups` (anon/authenticated) kini diverifikasi
-- terhadap status lisensi pemilik folder (`{googleUserId}/{productId}/...`):
--   - Akun TANPA lisensi apa pun          → diizinkan (user baru / belum link)
--   - Akun punya ≥1 lisensi USABLE        → diizinkan
--     (status Generated/Trial/Active DAN expires_at lewat → tolak)
--   - Akun hanya punya lisensi blocked    → DITOLAK (Cancelled/Suspended/Expired)
--     (restore "Data Ditemukan" kosong, auto-sync mati, upload gagal)
--
-- Konsisten dengan register_activation CHECK: satu lisensi buruk tidak menghukum
-- akun yang masih punya lisensi aktif lain.
--
-- Cek lisensi dibungkus SECURITY DEFINER function supaya policy (yang jalan
-- sebagai anon) tidak perlu grant SELECT ke tabel licenses (key harus tetap
-- rahasia). Function hanya mengekspos boolean.
--
-- CATATAN: ini memutus akses CLOUD saja — data lokal di device tetap ada.
-- Blokir penuh "tidak bisa masuk app" butuh cek lisensi di startup app
-- (perubahan Flutter, batch build berikutnya).
-- ============================================================================

begin;

-- 1. Helper: apakah folder_uid boleh pakai backup cloud?
create or replace function public.nusa_backup_allowed(folder_uid text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    not exists (
      select 1 from licenses l
      where l.google_user_id = folder_uid
    )
    or exists (
      select 1 from licenses l
      where l.google_user_id = folder_uid
        and l.status in ('Generated', 'Trial', 'Active')
        and (l.expires_at is null or l.expires_at > now())
    );
$$;

revoke all on function public.nusa_backup_allowed(text) from public;
grant execute on function public.nusa_backup_allowed(text) to anon, authenticated;

-- 2. Tulis ulang 4 policy nusa-backups (dari 0010/0011) dengan gate lisensi.
drop policy if exists "nusa_backups_insert" on storage.objects;
drop policy if exists "nusa_backups_select" on storage.objects;
drop policy if exists "nusa_backups_update" on storage.objects;
drop policy if exists "nusa_backups_delete" on storage.objects;

create policy "nusa_backups_insert" on storage.objects
  for insert to anon, authenticated
  with check (
    bucket_id = 'nusa-backups'
    and public.nusa_backup_allowed(split_part(name, '/', 1))
  );

create policy "nusa_backups_select" on storage.objects
  for select to anon, authenticated
  using (
    bucket_id = 'nusa-backups'
    and public.nusa_backup_allowed(split_part(name, '/', 1))
  );

create policy "nusa_backups_update" on storage.objects
  for update to anon, authenticated
  using (
    bucket_id = 'nusa-backups'
    and public.nusa_backup_allowed(split_part(name, '/', 1))
  )
  with check (
    bucket_id = 'nusa-backups'
    and public.nusa_backup_allowed(split_part(name, '/', 1))
  );

create policy "nusa_backups_delete" on storage.objects
  for delete to anon, authenticated
  using (
    bucket_id = 'nusa-backups'
    and public.nusa_backup_allowed(split_part(name, '/', 1))
  );

commit;
