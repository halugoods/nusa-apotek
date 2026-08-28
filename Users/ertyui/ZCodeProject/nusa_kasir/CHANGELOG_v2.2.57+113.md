# Changelog v2.2.57+113

## Optimasi Cached Egress (Supabase Storage)
- **App**: `syncAll()` & `uploadAllLocal()` di `image_storage_service.dart` tidak lagi
  probe-download berulang untuk file yang sudah diketahui ada (atau tidak ada) di
  cloud dalam sesi yang sama → mengurangi request egress saat start app.
- **nusa-online**: `fetchManifest()` tidak lagi memakai `cache: "no-store"` —
  manifest jarang berubah (version naik tiap update), jadi cache browser/CDN aman
  dipakai untuk mengurangi egress berulang.
- **nusa-online**: upload thumbnail tutorial kini men-set `Cache-Control:
  public, max-age=31536000, immutable` → CDN menyimpan thumbnail, tidak
  di-fetch ulang tiap render.

## Catatan
- Versi utama tetap 2.2.57 (hanya build number +113).
- Thumbnail lama di bucket `tutorial-thumbnails` perlu di-set cache header
  manual dari dashboard (panduan di chat) — baru upload berikutnya yang otomatis.
