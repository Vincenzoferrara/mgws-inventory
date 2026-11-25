import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xml/xml.dart';
import '../log_viewer/app_logger.dart';

class CalDavService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? baseUrl;
  String? username;
  String? password;
  Dio? dio;

  static const String _keySite = 'caldav_site';
  static const String _keyParameter = 'caldav_parameter';
  static const String _keyUsername = 'caldav_username';
  static const String _keyPassword = 'caldav_password';

  Future<void> loadCredentials() async {
    final site = await _storage.read(key: _keySite);
    final parameter = await _storage.read(key: _keyParameter);
    username = await _storage.read(key: _keyUsername);
    password = await _storage.read(key: _keyPassword);

    if (site != null && username != null && password != null) {
      baseUrl = _buildFullUrl(site, parameter ?? '');
      _configureDio();
    }
  }

  String _buildFullUrl(String site, String parameter) {
    final trimmed = site.trim();
    String base;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      base = trimmed;
    } else {
      base = 'https://$trimmed';
    }
    return parameter.isEmpty ? base : '$base$parameter';
  }

  /// True se l'URL e' sicuro per inviare credenziali Basic Auth
  /// (HTTPS, oppure HTTP solo su localhost/127.0.0.1 per sviluppo locale).
  bool _isSecureUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme == 'http') {
      final host = uri.host.toLowerCase();
      return host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1';
    }
    return false;
  }

  void _configureDio() {
    if (baseUrl == null || username == null || password == null) return;
    // Non inviare mai credenziali Basic Auth su HTTP non sicuro.
    if (!_isSecureUrl(baseUrl)) {
      dio = null;
      return;
    }
    final url = baseUrl!.endsWith('/') ? baseUrl! : '$baseUrl/';
    dio = Dio(
      BaseOptions(
        baseUrl: url,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$username:$password'))}',
          'Content-Type': 'application/xml',
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getCalendars() async {
    if (dio == null) return [];
    try {
      var response = await dio!.request(
        '/',
        options: Options(method: 'PROPFIND', headers: {'Depth': '1'}),
        data: '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <displayname/>
    <resourcetype/>
    <getctag xmlns="http://calendarserver.org/ns/"/>
  </prop>
</propfind>''',
      );
      var document = XmlDocument.parse(response.data);
      List<Map<String, dynamic>> calendars = [];
      for (var responseElement in document.findAllElements('response')) {
        var href = responseElement.findElements('href').first.innerText;
        var propstat = responseElement.findElements('propstat').first;
        var prop = propstat.findElements('prop').first;
        var displayName = prop
            .findElements('displayname')
            .firstOrNull
            ?.innerText;
        var resourceType = prop.findElements('resourcetype').first;
        if (resourceType
            .findElements(
              'calendar',
              namespace: 'urn:ietf:params:xml:ns:caldav',
            )
            .isNotEmpty) {
          var ctag = prop
              .findElements(
                'getctag',
                namespace: 'http://calendarserver.org/ns/',
              )
              .firstOrNull
              ?.innerText;
          calendars.add({
            'href': href,
            'displayName': displayName,
            'ctag': ctag,
          });
        }
      }
      return calendars;
    } catch (e) {
      log.e('CalDav: errore getCalendars', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTasks(String calendarHref) async {
    return await _getObjects(calendarHref, 'VTODO');
  }

  Future<List<Map<String, dynamic>>> getEvents(String calendarHref) async {
    return await _getObjects(calendarHref, 'VEVENT');
  }

  Future<List<Map<String, dynamic>>> _getObjects(
    String calendarHref,
    String component,
  ) async {
    if (dio == null) return [];
    try {
      var response = await dio!.request(
        calendarHref,
        options: Options(method: 'REPORT'),
        data:
            '''<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="$component"/>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>''',
      );
      var document = XmlDocument.parse(response.data);
      List<Map<String, dynamic>> objects = [];
      for (var responseElement in document.findAllElements('response')) {
        var href = responseElement.findElements('href').first.innerText;
        var propstat = responseElement.findElements('propstat').first;
        var prop = propstat.findElements('prop').first;
        var etag = prop.findElements('getetag').first.innerText;
        var calendarData = prop
            .findElements(
              'calendar-data',
              namespace: 'urn:ietf:params:xml:ns:caldav',
            )
            .first
            .innerText;

        // For now, return raw data, parsing later
        objects.add({'href': href, 'etag': etag, 'ical': calendarData});
      }
      return objects;
    } catch (e) {
      log.e('CalDav: errore get $component', e);
      return [];
    }
  }
}
