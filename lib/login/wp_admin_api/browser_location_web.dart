import 'dart:js_interop';

@JS('window.location.assign')
external void _assign(String url);

@JS('window.history.replaceState')
external void _replaceState(JSAny? data, String unused, String url);

/// Leaves the app for [url] in the same tab.
void browserGoTo(String url) => _assign(url);

/// Replaces the address bar with [url] without reloading.
void browserReplaceUrl(String url) => _replaceState(null, '', url);
