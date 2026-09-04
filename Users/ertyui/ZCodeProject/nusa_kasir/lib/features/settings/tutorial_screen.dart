import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/cloud/cloud_gateway.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tutorial — galeri video panduan, CLOUD ONLY (v2.2.54 redesign).
///
/// Konten dikelola dari nusa-online /dashboard → tab Tutorial (tabel
/// `tutorials` di Supabase) dan difilter per varian (NusaConfig.productId).
/// v2.2.54: 20 kartu teks statis DIHAPUS — kalau cloud kosong/gagal, tampil
/// empty state yang rapi dengan tombol coba lagi. Tampilan grid 2 kolom
/// thumbnail 16:9 ala YouTube dengan overlay play.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

enum _LoadState { loading, loaded, error }

class _TutorialScreenState extends State<TutorialScreen> {
  _LoadState _state = _LoadState.loading;
  List<TutorialItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchCloud();
  }

  Future<void> _fetchCloud() async {
    setState(() => _state = _LoadState.loading);
    try {
      // Gateway endpoint `tutorial-manager` action `list` — mengembalikan
      // rows JSON tabel `tutorials` (id,title,yt_url,thumbnail_url,
      // description,variants,sort_order) yang sudah difilter per varian
      // + terurut (sort_order asc, created_at desc).
      final res = await CloudGateway.shared.invokeRaw(
        'tutorial-manager',
        'list',
        body: {'variant': NusaConfig.productId},
      );
      final data = res.data;
      final rows = data is List
          ? data
          : (data is Map ? (data['rows'] ?? data['tutorials']) : null);
      if (res.status >= 400 || rows is! List) {
        throw Exception('tutorial list gagal (${res.status})');
      }
      if (!mounted) return;
      setState(() {
        _items = rows
            .whereType<Map>()
            .map((r) => TutorialItem.fromRow(
                  Map<String, dynamic>.from(r),
                ))
            .toList();
        _state = _LoadState.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScreenScaffold(
      'Tutorial',
      RefreshIndicator(
        onRefresh: _fetchCloud,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Video panduan cara pakai NUSA Kasir — ketuk untuk '
                  'menonton di YouTube.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                ),
              ),
            ),
            switch (_state) {
              _LoadState.loading => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              _LoadState.error => SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(
                  isDark,
                  icon: Icons.wifi_off_rounded,
                  title: 'Gagal memuat tutorial',
                  subtitle:
                      'Periksa koneksi internet lalu tarik ke bawah atau '
                      'tekan tombol di bawah untuk mencoba lagi.',
                  actionLabel: 'Coba Lagi',
                  onAction: _fetchCloud,
                ),
              ),
              _LoadState.loaded when _items.isEmpty => SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(
                  isDark,
                  icon: Icons.video_library_outlined,
                  title: 'Belum ada video panduan',
                  subtitle:
                      'Video tutorial sedang disiapkan dan akan muncul '
                      'otomatis di sini begitu dipublikasikan.',
                ),
              ),
              _LoadState.loaded => SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _videoCard(_items[i], isDark),
                    childCount: _items.length,
                  ),
                ),
              ),
            },
          ],
        ),
      ),
    );
  }

  /// Kartu video gaya galeri YouTube: thumbnail 16:9 + overlay play +
  /// judul & deskripsi singkat di bawah.
  Widget _videoCard(TutorialItem item, bool isDark) {
    return GestureDetector(
      onTap: item.openable
          ? () => launchUrl(
                Uri.parse(item.launchUrl!),
                mode: LaunchMode.externalApplication,
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail 16:9
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.thumbOrFallback != null
                      ? Image.network(
                          item.thumbOrFallback!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _thumbPlaceholder(isDark),
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null
                              ? child
                              : _thumbPlaceholder(isDark),
                        )
                      : _thumbPlaceholder(isDark),
                  // Overlay gelap tipis biar ikon play kontras
                  Container(color: Colors.black.withValues(alpha: 0.18)),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: NusaConfig.activePrimary.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(
                          NusaConfig.radiusFull,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
            ),
          ),
          if (item.text.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: isDark
                    ? NusaConfig.darkTextTertiary
                    : NusaConfig.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(bool isDark) {
    return Container(
      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.backgroundColor,
      child: Icon(
        Icons.movie_outlined,
        size: 32,
        color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
      ),
    );
  }

  Widget _emptyState(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: NusaConfig.activePrimary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? NusaConfig.darkTextPrimary
                  : NusaConfig.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: isDark
                  ? NusaConfig.darkTextSecondary
                  : NusaConfig.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: NusaConfig.activePrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Data satu video tutorial dari tabel `tutorials` (Supabase).
class TutorialItem {
  final String key;
  final String title;
  final String text;
  final String? launchUrl; // link YouTube yang dibuka saat kartu diketuk
  final String? thumbnailUrl; // gambar preview (opsional, dari dashboard)

  const TutorialItem({
    required this.key,
    required this.title,
    required this.text,
    this.launchUrl,
    this.thumbnailUrl,
  });

  bool get openable => launchUrl != null && launchUrl!.isNotEmpty;

  /// Thumbnail tampilan: pakai thumbnail_url dari dashboard; kalau kosong,
  /// turunkan otomatis dari URL YouTube (img.youtube.com/vi/<id>/hqdefault).
  String? get thumbOrFallback {
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) {
      return thumbnailUrl;
    }
    final id = _youtubeId(launchUrl);
    if (id != null) return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    return null;
  }

  static String? _youtubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final patterns = [
      RegExp(r'youtu\.be/([A-Za-z0-9_-]{6,})'),
      RegExp(r'[?&]v=([A-Za-z0-9_-]{6,})'),
      RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{6,})'),
      RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{6,})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Bangun item dari baris tabel `tutorials` (supabase).
  factory TutorialItem.fromRow(Map<String, dynamic> r) {
    return TutorialItem(
      key: (r['id'] as String?) ?? '',
      title: (r['title'] as String?) ?? 'Tutorial',
      text: (r['description'] as String?) ?? '',
      launchUrl: r['yt_url'] as String?,
      thumbnailUrl: r['thumbnail_url'] as String?,
    );
  }
}
