String formatRupiah(num value) {
  final abs = value.abs().round();
  final digits = abs.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
  return '${value < 0 ? '-' : ''}Rp $digits';
}
