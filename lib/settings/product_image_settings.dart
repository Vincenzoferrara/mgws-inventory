import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductImageWarningSettings extends ChangeNotifier {
  static const String _warningEnabledKey =
      'product_image_dimension_warning_enabled';
  static const String _warningWidthKey = 'img_resize_width';
  static const String _warningHeightKey = 'img_resize_height';

  bool _warningsEnabled = true;
  int _thresholdWidth = 720;
  int _thresholdHeight = 1080;

  bool get warningsEnabled => _warningsEnabled;
  int get thresholdWidth => _thresholdWidth;
  int get thresholdHeight => _thresholdHeight;

  Future<void> init() async {
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _warningsEnabled = prefs.getBool(_warningEnabledKey) ?? true;
    _thresholdWidth = prefs.getInt(_warningWidthKey) ?? 720;
    _thresholdHeight = prefs.getInt(_warningHeightKey) ?? 1080;
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_warningEnabledKey, _warningsEnabled);
    await prefs.setInt(_warningWidthKey, _thresholdWidth);
    await prefs.setInt(_warningHeightKey, _thresholdHeight);
  }

  Future<void> setWarningsEnabled(bool value) async {
    if (_warningsEnabled == value) return;
    _warningsEnabled = value;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setThresholdWidth(int value) async {
    final normalized = value < 0 ? 0 : value;
    if (_thresholdWidth == normalized) return;
    _thresholdWidth = normalized;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setThresholdHeight(int value) async {
    final normalized = value < 0 ? 0 : value;
    if (_thresholdHeight == normalized) return;
    _thresholdHeight = normalized;
    await _savePreferences();
    notifyListeners();
  }
}

bool isProductImageOverWarningThreshold({
  required int? width,
  required int? height,
  required bool warningsEnabled,
  required int thresholdWidth,
  required int thresholdHeight,
}) {
  if (!warningsEnabled || width == null || height == null) return false;

  final exceedsWidth = thresholdWidth > 0 && width > thresholdWidth;
  final exceedsHeight = thresholdHeight > 0 && height > thresholdHeight;
  return exceedsWidth || exceedsHeight;
}
