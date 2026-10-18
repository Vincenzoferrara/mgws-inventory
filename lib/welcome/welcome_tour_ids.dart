/// Identity of every guided tour shipped by the welcome module.
///
/// This enum is the single source of truth for tour identity and for the
/// versioned preference key owned by each tour. It deliberately excludes the
/// CalDAV, log viewer, shared barcode/QR scanner, RFID, AI and updater
/// modules: those areas are not part of the guided tour set.
enum WelcomeTourId {
  overview,
  login,
  home,
  productManagement,
  productCreation,
  inventory,
  cashier,
  orders,
  customers,
  suppliers,
  loyalty,
  coupons,
  reports,
  dashboard,
  employees,
  settings;

  /// Namespace and schema version shared by every welcome preference key.
  ///
  /// Bumping the version makes a materially changed tour start again without
  /// touching the keys of the previous version.
  static const String preferenceKeyPrefix = 'welcome.v1';

  /// Suffix that marks a key as a tour completion flag.
  static const String preferenceKeySuffix = '.completed';

  /// Versioned preference key of this tour: `welcome.v1.<tourId>.completed`.
  ///
  /// The key belongs to the welcome module only, so it can be removed safely
  /// without touching unrelated preferences.
  String get preferenceKey => '$preferenceKeyPrefix.$name$preferenceKeySuffix';
}
