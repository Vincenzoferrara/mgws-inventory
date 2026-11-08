import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/login/wp_admin_api/wp_authorize_app.dart';

void main() {
  group('wpAuthorizeApplicationUrl', () {
    test('points to the WordPress approval page and comes back to the app', () {
      final url = wpAuthorizeApplicationUrl(
        siteUrl: 'http://localhost:8080/',
        returnUrl: Uri.parse('http://127.0.0.1:8094/?old=1#/home'),
      );

      expect(url.scheme, 'http');
      expect(url.host, 'localhost');
      expect(url.port, 8080);
      expect(url.path, '/wp-admin/authorize-application.php');
      expect(url.queryParameters['app_name'], wpAuthorizeAppName);
      expect(url.queryParameters['app_id'], wpAuthorizeAppId);
      expect(url.queryParameters['success_url'], 'http://127.0.0.1:8094/');
      expect(url.queryParameters['reject_url'], 'http://127.0.0.1:8094/');
    });

    test('keeps a site installed in a subfolder', () {
      final url = wpAuthorizeApplicationUrl(
        siteUrl: 'https://shop.example.com/wp',
        returnUrl: Uri.parse('https://app.example.com/pos/'),
      );

      expect(
        url.toString(),
        startsWith(
          'https://shop.example.com/wp/wp-admin/authorize-application.php?',
        ),
      );
      expect(
        url.queryParameters['success_url'],
        'https://app.example.com/pos/',
      );
    });
  });

  group('wpAuthorizeAnswerFromUri', () {
    test('approval carries user and application password', () {
      final answer = wpAuthorizeAnswerFromUri(
        Uri.parse(
          'http://127.0.0.1:8094/?site_url=http%3A%2F%2Flocalhost%3A8080'
          '&user_login=mgws_test&password=abcd%20efgh%20ijkl',
        ),
      );

      expect(answer, isA<WpAuthorizeApproved>());
      final approved = answer as WpAuthorizeApproved;
      expect(approved.siteUrl, 'http://localhost:8080');
      expect(approved.userLogin, 'mgws_test');
      expect(approved.password, 'abcd efgh ijkl');
    });

    test('refusal', () {
      expect(
        wpAuthorizeAnswerFromUri(
          Uri.parse('http://127.0.0.1:8094/?success=false'),
        ),
        isA<WpAuthorizeRejected>(),
      );
    });

    test('a normal start carries no answer', () {
      expect(
        wpAuthorizeAnswerFromUri(Uri.parse('http://127.0.0.1:8094/')),
        isNull,
      );
      expect(
        wpAuthorizeAnswerFromUri(
          Uri.parse('http://127.0.0.1:8094/?user_login=x&password='),
        ),
        isNull,
      );
    });
  });

  test('wpAuthorizeReturnUrl drops the answer from the address', () {
    expect(
      wpAuthorizeReturnUrl(
        Uri.parse('http://127.0.0.1:8094/?user_login=a&password=b#/x'),
      ).toString(),
      'http://127.0.0.1:8094/',
    );
    expect(
      wpAuthorizeReturnUrl(Uri.parse('https://app.example.com')).toString(),
      'https://app.example.com/',
    );
  });
}
