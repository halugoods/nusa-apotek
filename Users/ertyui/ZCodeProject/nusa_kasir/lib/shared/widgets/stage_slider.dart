import 'package:flutter/material.dart';

/// A horizontally-scrollable stage/tab slider with animated indicator.
///
/// Use this instead of TabBar when you have 4+ stages and need all tabs
/// to fill available width without empty space. Each tab shows a label
/// and optional count badge.
///
/// Usage:
/// ```dart
/// StageSlider(
///   stages: [
///     StageData(label: 'Baru', color: Colors.purple, count: 3),
///     StageData(label: 'Cuci', color: Colors.blue, count: 5),
///     ...
///   ],
///   selectedIndex: 0,
///   onChanged: (index) { },
/// )
/// ```
class StageData {
  final String label;
  final Color color;
  final int count;
  const StageData({required this.label, required this.color, this.count = 0});
}

class StageSlider extends StatelessWidget {
  final List<StageData> stages;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const StageSlider({
    super.key,
    required this.stages,
    required this.selectedIndex,
    required this.onChanged,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // Distribute tabs evenly: each tab gets equal width
    // Use ListView for horizontal scroll when needed
    final tabCount = stages.length;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A3A52)
              : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: tabCount <= 6
          ? _buildEvenTabs()
          : _buildScrollableTabs(),
    );
  }

  /// When tabs fit comfortably (≤6), distribute evenly with Row.
  Widget _buildEvenTabs() {
    return Row(
      children: List.generate(stages.length, (i) {
        final stage = stages[i];
        final selected = i == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: selected ? stage.color : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      stage.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280)),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (stage.count > 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${stage.count}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white.withOpacity(0.8)
                            : stage.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  /// When too many tabs (>6), fall back to scrollable list.
  Widget _buildScrollableTabs() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: stages.length,
      itemBuilder: (_, i) {
        final stage = stages[i];
        final selected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? stage.color : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stage.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280)),
                  ),
                ),
                if (stage.count > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${stage.count}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withOpacity(0.8)
                          : stage.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
