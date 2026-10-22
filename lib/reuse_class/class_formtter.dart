import '../l10n/generated/app_localizations.dart';

class ClassFormtter {
  static String formatPrezzo(double prezzo) {
    return '€${prezzo.toStringAsFixed(2)}';
  }

  static String getDisponibilitaText(AppLocalizations l10n, bool inStock) {
    return inStock ? l10n.productsAvailable : l10n.productsSoldOut;
  }

  static String getVariantiCountText(AppLocalizations l10n, int count) {
    return l10n.productsVariantCount(count);
  }

  static String getVariantiCountShort(int count) {
    return '$count var.';
  }
}
