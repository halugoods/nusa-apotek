/// Normalize an Indonesian phone number into the international format
/// expected by wa.me links (e.g. 0812345678 → 62812345678).
///
/// Rules:
/// - strip every non-digit character
/// - leading `0`  → replace with `62`
/// - already starts with `62` → keep as-is
/// - anything else → prepend `62`
String normalizeWaPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('0')) return '62${digits.substring(1)}';
  if (digits.startsWith('62')) return digits;
  return '62$digits';
}
