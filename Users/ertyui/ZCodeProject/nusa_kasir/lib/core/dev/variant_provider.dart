import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/dev/variant_data.dart';

/// Holds the currently selected variant for dev mode.
class VariantState {
  final VariantData data;
  const VariantState(this.data);
}

class VariantNotifier extends StateNotifier<VariantState?> {
  VariantNotifier() : super(null);

  void select(VariantData variant) {
    state = VariantState(variant);
    NusaConfig.applyDevVariant(variant);
  }

  void clear() {
    state = null;
    NusaConfig.clearDevVariant();
  }
}

final variantProvider = StateNotifierProvider<VariantNotifier, VariantState?>(
  (ref) => VariantNotifier(),
);
