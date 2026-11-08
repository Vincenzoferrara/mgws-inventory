// browser_location.dart
//
// Address bar of the browser, used by the web login through WordPress.
// On the other platforms these calls do nothing.

export 'browser_location_stub.dart'
    if (dart.library.js_interop) 'browser_location_web.dart';
