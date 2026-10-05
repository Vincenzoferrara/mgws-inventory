import 'package:shared_preferences/shared_preferences.dart';

/// UI preferences that belong to the current machine only.
///
/// These values are intentionally kept out of [AppSettings] because they must
/// not be synced to WordPress or shown in the settings UI.
class MachineUiPreferences {
  static const String _productsManageSplitRatioKey =
      'machine_products_manage_split_ratio';

  static const double defaultProductsManageSplitRatio = 0.60;
  static const double minProductsManageSplitRatio = 0.45;
  static const double maxProductsManageSplitRatio = 0.75;

  double _productsManageSplitRatio = defaultProductsManageSplitRatio;

  double get productsManageSplitRatio => _productsManageSplitRatio;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _productsManageSplitRatio = normalizeProductsManageSplitRatio(
      prefs.getDouble(_productsManageSplitRatioKey) ??
          defaultProductsManageSplitRatio,
    );
  }

  Future<void> setProductsManageSplitRatio(double value) async {
    final normalized = normalizeProductsManageSplitRatio(value);
    if (_productsManageSplitRatio == normalized) return;
    _productsManageSplitRatio = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_productsManageSplitRatioKey, normalized);
  }

  static double normalizeProductsManageSplitRatio(double value) {
    return value.clamp(
      minProductsManageSplitRatio,
      maxProductsManageSplitRatio,
    );
  }
}
