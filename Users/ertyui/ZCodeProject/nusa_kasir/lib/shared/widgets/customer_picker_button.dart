import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/contact_picker.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';

/// Result of a customer picked via the customer picker sheet.
/// [name] & [phone] come from the in-app customer list (or the device
/// contact book if the "Kontak" tab is used).
class CustomerPickResult {
  final String name;
  final String phone;
  const CustomerPickResult({required this.name, required this.phone});
}

/// "Pilih Pelanggan" button — mirrors the Tambah Pelanggan form pattern
/// (contacts icon + self-aligned height to the search bar).
///
/// Opens a bottom sheet with two tabs:
/// - **Pelanggan**: searchable list of saved customers (in-app).
/// - **Kontak**: opens the native device contact picker.
///
/// The button is 42×42 (same height as the search bar) so it stays
/// perfectly aligned next to the search field — the "pelanggan picker"
/// style instead of a bare contact icon.
class CustomerPickerButton extends ConsumerStatefulWidget {
  final ValueChanged<CustomerPickResult> onPick;
  final bool alignEnd;

  const CustomerPickerButton({
    super.key,
    required this.onPick,
    this.alignEnd = true,
  });

  @override
  ConsumerState<CustomerPickerButton> createState() => _CustomerPickerButtonState();
}

class _CustomerPickerButtonState extends ConsumerState<CustomerPickerButton> {
  Future<void> _open() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.read(databaseProvider);
    final customers = await CustomerRepository(db).getCustomers();
    if (!mounted) return;

    String pickerQuery = '';
    List<Customer> filtered = List.from(customers);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.6,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(children: [
              // Drag handle
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Pilih Pelanggan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              // Search
              // Search — search bar standar (NusaSearchBar) tanpa controller
              // eksplisit; filter tetap via setSheet di onChanged.
              NusaSearchBar(
                autofocus: true,
                hint: 'Cari nama atau telepon...',
                onChanged: (v) => setSheet(() {
                  pickerQuery = v.toLowerCase();
                  filtered = customers.where((c) => c.name.toLowerCase().contains(pickerQuery) || (c.phone ?? '').contains(pickerQuery)).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('Tidak ada pelanggan', style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: NusaConfig.activePrimary.withOpacity(0.1),
                              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: TextStyle(fontWeight: FontWeight.w700, color: NusaConfig.activePrimary, fontSize: 14)),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: c.phone != null && c.phone!.isNotEmpty ? Text(c.phone!, style: const TextStyle(fontSize: 12)) : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              widget.onPick(CustomerPickResult(name: c.name, phone: c.phone ?? ''));
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              // Contact book shortcut
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final contact = await pickContact();
                    if (contact != null) {
                      widget.onPick(CustomerPickResult(name: contact['name'] ?? '', phone: contact['phone'] ?? ''));
                    }
                  },
                  icon: const Icon(Icons.contacts_outlined, size: 18),
                  label: const Text('Pilih dari Kontak HP'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NusaConfig.activePrimary,
                    side: BorderSide(color: NusaConfig.activePrimary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _open,
      child: Container(
        width: 42,
        height: 42,
        alignment: widget.alignEnd ? Alignment.center : null,
        decoration: BoxDecoration(
          color: NusaConfig.activePrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
        ),
        child: Icon(Icons.contacts_outlined, color: NusaConfig.activePrimary, size: 20),
      ),
    );
  }
}
