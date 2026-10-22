import '../../l10n/localized_text.dart';

class UrlValidator {
  /// Controlla se un host è un IP locale o riservato.
  static bool isLocalOrReservedIp(String host) {
    if (host.toLowerCase() == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1')
      return true;

    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(host)) return false;

    final parts = host.split('.').map((p) => int.tryParse(p) ?? 256).toList();
    if (parts.any((p) => p > 255)) return false;

    if (parts[0] == 10) return true;
    if (parts[0] == 127) return true;
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    if (parts[0] == 192 && parts[1] == 168) return true;

    return false;
  }

  /// Valida un URL completo.
  /// Restituisce `null` se l'URL e valido, altrimenti il motivo tradotto.
  static LocalizedText? validateUrl(
    String? value, {
    bool allowLocalhost = false,
  }) {
    if (value == null || value.isEmpty) {
      return (l10n) => l10n.loginEnterSiteUrl;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute) {
      return allowLocalhost
          ? (l10n) => l10n.loginInvalidUrlLocal
          : (l10n) => l10n.loginInvalidUrl;
    }

    bool isLocal = isLocalOrReservedIp(uri.host);

    if (isLocal && !allowLocalhost) {
      return (l10n) => l10n.loginLocalNeedsDevMode;
    }

    if (!isLocal && uri.scheme != 'https') {
      return (l10n) => l10n.loginExternalNeedsHttps;
    }

    return null; // L'URL è valido
  }
}
