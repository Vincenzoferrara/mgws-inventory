// wp_authorize_app.dart
//
// Web login through the WordPress "Authorize Application" page
// (/wp-admin/authorize-application.php, WordPress 5.6+).
//
// In the browser the app cannot log in with the normal password (no cookies
// from /wp-login.php across origins), and WordPress accepts only Application
// Passwords in Basic Auth. So the browser goes to the WordPress page, the user
// logs in there with the normal password and approves the app, and WordPress
// comes back to the app URL with `user_login` and `password` (a new
// Application Password) in the query.
//
// This file holds only the pure parts: building the URL and reading the
// answer. Navigation and storage live in login.code.dart.

/// SharedPreferences key: site the user asked to authorize, set just before
/// leaving the app. An answer without it is ignored.
const wpAuthorizePendingSiteKey = 'wp_authorize_pending_site';

/// Name shown by WordPress on the approval page and in the profile list.
const wpAuthorizeAppName = 'MGWS Inventory';

/// Fixed id of this app, so WordPress groups its passwords together.
const wpAuthorizeAppId = '6f1d3c2a-8b4e-4f7a-9c5d-2e8b1a0f4d37';

/// The app page without query and fragment: where WordPress comes back to,
/// and what goes back in the address bar after reading the answer, so the
/// password does not stay in the browser history.
Uri wpAuthorizeReturnUrl(Uri current) => _withoutQuery(current);

/// The WordPress approval page for [siteUrl], coming back to [returnUrl]
/// both on approval and on refusal.
Uri wpAuthorizeApplicationUrl({
  required String siteUrl,
  required Uri returnUrl,
}) {
  final base = siteUrl.endsWith('/')
      ? siteUrl.substring(0, siteUrl.length - 1)
      : siteUrl;
  final back = wpAuthorizeReturnUrl(returnUrl).toString();
  return Uri.parse('$base/wp-admin/authorize-application.php').replace(
    queryParameters: {
      'app_name': wpAuthorizeAppName,
      'app_id': wpAuthorizeAppId,
      'success_url': back,
      'reject_url': back,
    },
  );
}

/// What WordPress sent back to the app.
sealed class WpAuthorizeAnswer {
  const WpAuthorizeAnswer();
}

/// The user approved: [password] is a new Application Password.
class WpAuthorizeApproved extends WpAuthorizeAnswer {
  final String siteUrl;
  final String userLogin;
  final String password;

  const WpAuthorizeApproved({
    required this.siteUrl,
    required this.userLogin,
    required this.password,
  });
}

/// The user pressed "No, I do not approve".
class WpAuthorizeRejected extends WpAuthorizeAnswer {
  const WpAuthorizeRejected();
}

/// Reads the WordPress answer from the app URL, or null when [uri] carries
/// none (a normal start of the app).
WpAuthorizeAnswer? wpAuthorizeAnswerFromUri(Uri uri) {
  final q = uri.queryParameters;
  final user = q['user_login'];
  final password = q['password'];
  if (user != null &&
      user.isNotEmpty &&
      password != null &&
      password.isNotEmpty) {
    return WpAuthorizeApproved(
      siteUrl: q['site_url'] ?? '',
      userLogin: user,
      password: password,
    );
  }
  if (q['success'] == 'false') return const WpAuthorizeRejected();
  return null;
}

Uri _withoutQuery(Uri uri) => Uri(
  scheme: uri.scheme,
  host: uri.host,
  port: uri.hasPort ? uri.port : null,
  path: uri.path.isEmpty ? '/' : uri.path,
);
