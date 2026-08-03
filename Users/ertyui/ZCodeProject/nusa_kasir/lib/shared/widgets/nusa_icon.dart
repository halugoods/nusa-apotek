import 'package:flutter/material.dart';
class NusaIcons {
  static const Map<String, IconData> _map = {
    'home': Icons.home_outlined,
    'cashier': Icons.point_of_sale_outlined,
    'product': Icons.inventory_2_outlined,
    'inventory': Icons.view_module_outlined,
    'transaction': Icons.receipt_long_outlined,
    'customer': Icons.people_outline,
    'promotion': Icons.local_offer_outlined,
    'message': Icons.chat_bubble_outline,
    'finance': Icons.paid_outlined,
    'settings': Icons.settings_outlined,
    'barcode': Icons.qr_code_2_outlined,
    'camera': Icons.camera_alt_outlined,
    'notification': Icons.notifications_outlined,
    'supplier': Icons.local_shipping_outlined,
    'table': Icons.table_chart_outlined,
    'employee': Icons.people_alt_outlined,
  };
  static IconData get(String name) => _map[name] ?? Icons.circle_outlined;
  static Widget icon(String name, {double size = 28, Color? color}) =>
    Icon(get(name), size: size, color: color);
}
