import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/product_discount.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/features/products/product_form_screen.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_status_badge.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Filtered products by category screen.
/// Route: /produk/kategori/:category
class ProductsByCategoryScreen extends ConsumerStatefulWidget {
  final String category;
  ProductsByCategoryScreen({required this.category, super.key});
  @override
  ConsumerState<ProductsByCategoryScreen> createState() =>
      _ProductsByCategoryScreenState();
}

class _ProductsByCategoryScreenState
    extends ConsumerState<ProductsByCategoryScreen> {
  List<Product> _products = [];
  bool _loading = true;
  final _search = TextEditingController();
  _SortBy _sortBy = _SortBy.nameAsc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ProductRepository(ref.read(databaseProvider));
    final all = await repo.getProducts(category: widget.category);
    if (mounted)
      setState(() {
        _products = _sort(all);
        _loading = false;
      });
  }

  List<Product> _sort(List<Product> list) {
    switch (_sortBy) {
      case _SortBy.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _SortBy.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case _SortBy.priceHigh:
        list.sort((a, b) => b.sellPrice.compareTo(a.sellPrice));
      case _SortBy.priceLow:
        list.sort((a, b) => a.sellPrice.compareTo(b.sellPrice));
    }
    return list;
  }

  List<Product> get _filtered {
    final q = _search.text.toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emoji = NusaConfig.catEmojiFor(widget.category);
    final items = _filtered;

    return ScreenScaffold(
      '$emoji  ${widget.category}',
      Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                // Sort
                DropdownButtonHideUnderline(
                  child: DropdownButton<_SortBy>(
                    value: _sortBy,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                    items: _sortLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        setState(() {
                          _sortBy = v;
                          _products = _sort(_products);
                        });
                    },
                  ),
                ),
                Spacer(),
                Text(
                  '${items.length} produk',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? SkeletonList()
                : items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: NusaConfig.textTertiary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tidak ada produk di kategori ini',
                          style: TextStyle(
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10),
                      itemBuilder: (_, i) => _ProductCard(
                        product: items[i],
                        onEdit: () => showProductFormSheet(
                          context,
                          productId: items[i].id,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sort enum & labels ──

enum _SortBy { nameAsc, nameDesc, priceHigh, priceLow }

const _sortLabels = <_SortBy, String>{
  _SortBy.nameAsc: 'Nama (A-Z)',
  _SortBy.nameDesc: 'Nama (Z-A)',
  _SortBy.priceHigh: 'Harga (Tertinggi)',
  _SortBy.priceLow: 'Harga (Terendah)',
};

// ── Product Card ──

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  _ProductCard({required this.product, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage =
        product.imagePath != null &&
        product.imagePath!.isNotEmpty &&
        File(product.imagePath!).existsSync();

    return NusaCard(
      onTap: onEdit,
      Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
            child: SizedBox(
              width: 56,
              height: 56,
              child: hasImage
                  ? Image.file(
                      File(product.imagePath!),
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: NusaConfig.catGradientFor(product.category),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          NusaConfig.catEmojiFor(product.category),
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(width: NusaConfig.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  product.category,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                product.hasDiscount
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatRupiah(product.effectivePrice),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: NusaConfig.activePrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              formatRupiah(product.sellPrice),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        formatRupiah(product.sellPrice),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: NusaConfig.activePrimary,
                        ),
                      ),
              ],
            ),
          ),
          SizedBox(width: NusaConfig.spaceXS),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NusaStatusBadge(stock: product.stock, minStock: product.minStock),
              SizedBox(height: 4),
              Text(
                'Stok: ${product.stock}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ),
              SizedBox(height: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark
                    ? NusaConfig.darkTextTertiary
                    : NusaConfig.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
