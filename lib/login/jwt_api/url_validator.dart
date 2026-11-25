import '../../l10n/localized_text.dart';

class UrlValidator {
  /// Controlla se un host è un IP locale o riservato (SSRF protection).
  ///
  /// Copre localhost, loopback, reti private (RFC 1918), link-local,
  /// multicast, reserved, CGNAT, TEST-NET e IPv6 locali.
  static bool isLocalOrReservedIp(String host) {
    final h = host.toLowerCase().trim();
    if (h == 'localhost' || h == '127.0.0.1' || h == '::1') return true;
    if (h == '0.0.0.0' || h == '255.255.255.255') return true;

    // IPv6 locali / link-local / unique-local
    if (h.startsWith('fe80:') || h.startsWith('fc') || h.startsWith('fd')) {
      return true;
    }
    if (h.startsWith('::ffff:')) {
      // IPv4-mapped: controlla la parte IPv4
      final v4 = h.substring('::ffff:'.length);
      if (isLocalOrReservedIp(v4)) return true;
    }

    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(h)) return false;

    final parts = h.split('.').map((p) => int.tryParse(p) ?? 256).toList();
    if (parts.any((p) => p > 255)) return false;

    // 0.0.0.0/8
    if (parts[0] == 0) return true;
    // 10.0.0.0/8
    if (parts[0] == 10) return true;
    // 100.64.0.0/10 (CGNAT)
    if (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127) return true;
    // 127.0.0.0/8
    if (parts[0] == 127) return true;
    // 169.254.0.0/16 (link-local)
    if (parts[0] == 169 && parts[1] == 254) return true;
    // 172.16.0.0/12
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    // 192.0.0.0/24
    if (parts[0] == 192 && parts[1] == 0 && parts[2] == 0) return true;
    // 192.0.2.0/24 (TEST-NET-1)
    if (parts[0] == 192 && parts[1] == 0 && parts[2] == 2) return true;
    // 192.168.0.0/16
    if (parts[0] == 192 && parts[1] == 168) return true;
    // 198.18.0.0/15 (benchmarking)
    if (parts[0] == 198 && (parts[1] == 18 || parts[1] == 19)) return true;
    // 198.51.100.0/24 (TEST-NET-2)
    if (parts[0] == 198 && parts[1] == 51 && parts[2] == 100) return true;
    // 203.0.113.0/24 (TEST-NET-3)
    if (parts[0] == 203 && parts[1] == 0 && parts[2] == 113) return true;
    // 224.0.0.0/4 (multicast) e 240.0.0.0/4 (reserved)
    if (parts[0] >= 224) return true;

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
