// login_local_dev.code.dart
//
// Remembers the "local development connections" checkbox of the login, next
// to the saved site URL.
//
// Only for local addresses: the checkbox lowers the https requirement, so it
// must never come back by itself on a public site.

import 'package:shared_preferences/shared_preferences.dart';

import '../jwt_api/url_validator.dart';

const loginPrefKeyAllowLocalDev = 'login_allow_local_dev';

/// True when [siteUrl] points to a local or private address
/// (localhost, 127.x, 10.x, 172.16-31.x, 192.168.x), with or without scheme.
bool loginIsLocalSiteUrl(String siteUrl) {
  final trimmed = siteUrl.trim();
  if (trimmed.isEmpty) return false;
  final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final host = Uri.tryParse(withScheme)?.host ?? '';
  return host.isNotEmpty && UrlValidator.isLocalOrReservedIp(host);
}

/// Stores the checkbox after a successful login: kept only when it was on and
/// the site is local, otherwise cleared.
Future<void> loginSaveAllowLocalDev(
  SharedPreferences prefs, {
  required String siteUrl,
  required bool allowed,
}) async {
  if (allowed && loginIsLocalSiteUrl(siteUrl)) {
    await prefs.setBool(loginPrefKeyAllowLocalDev, true);
  } else {
    await prefs.remove(loginPrefKeyAllowLocalDev);
  }
}

/// The checkbox to show for the saved [siteUrl]: on only if it was saved on
/// and the URL is still a local one.
bool loginLoadAllowLocalDev(
  SharedPreferences prefs, {
  required String siteUrl,
}) =>
    (prefs.getBool(loginPrefKeyAllowLocalDev) ?? false) &&
    loginIsLocalSiteUrl(siteUrl);
