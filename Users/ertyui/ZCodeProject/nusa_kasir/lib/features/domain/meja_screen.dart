/// F&B: Table management — cinema-seat grid layout.
/// Owner can customize grid size and table names.
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

class MejaScreen extends StatefulWidget {
  const MejaScreen({super.key});

  @override
  State<MejaScreen> createState() => _MejaScreenState();
}

class _MejaScreenState extends State<MejaScreen> {
  int _gridCols = 4;
  int _gridRows = 3;
  final List<String> _tableNames = [];

  @override
  void initState() {
    super.initState();
    _initTables();
  }

  void _initTables() {
    _tableNames.clear();
    for (var i = 0; i < _gridCols * _gridRows; i++) {
      _tableNames.add('Meja ${i + 1}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Meja & Ruangan',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _sizePicker('Kolom', _gridCols, (v) => setState(() { _gridCols = v; _initTables(); })),
            const SizedBox(width: 16),
            _sizePicker('Baris', _gridRows, (v) => setState(() { _gridRows = v; _initTables(); })),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _tableNames.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridCols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.table_bar, size: 32, color: NusaConfig.primaryColor),
                  const SizedBox(height: 8),
                  Text(_tableNames[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Kosong', style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sizePicker(String label, int value, ValueChanged<int> onChanged) {
    return Expanded(
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        DropdownButton<int>(
          value: value,
          items: List.generate(8, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
          onChanged: (v) => onChanged(v!),
        ),
      ]),
    );
  }
}
