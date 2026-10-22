import 'package:docking/docking.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../login/gui/login.code.dart';
import '../login/mgws/connection/mgws_auth.dart';
import '../log_viewer/app_logger.dart';
import '../notification/notification_center.dart';
import '../users/class_user_global.dart';

const double homeSmallScreenBreakpoint = 768;

enum HomeTabOpenMode { singleton, duplicate }

class HomeTabMeta {
  HomeTabMeta({
    required this.id,
    required this.sectionId,
    required this.baseTitle,
    required this.isHome,
    this.istanza = 0,
  }) : displayTitle = _titoloConSuffisso(baseTitle, istanza);

  /// Suffisso dell'istanza, vuoto quando la scheda non ne porta.
  static String _titoloConSuffisso(String titolo, int istanza) =>
      istanza > 1 ? '$titolo #$istanza' : titolo;

  final String id;
  final String sectionId;
  final bool isHome;

  /// Titolo della sezione, senza il suffisso dell'istanza.
  String baseTitle;

  /// Titolo mostrato sulla scheda, sempre derivato da [baseTitle] e [istanza]
  /// perche i due non possano divergere.
  String displayTitle;

  /// Ordinale dell'istanza aperta per la stessa sezione.
  ///
  /// Vale 0 quando la scheda non porta suffisso. Resta invariato al cambio
  /// lingua, quindi chiudere una scheda non rinumera le altre rimaste aperte.
  final int istanza;

  /// Riscrive il titolo nella lingua indicata conservando il suffisso.
  void aggiornaTitolo(String titolo) {
    baseTitle = titolo;
    displayTitle = _titoloConSuffisso(titolo, istanza);
  }
}

class HomeLogic extends ChangeNotifier {
  HomeLogic({
    required this.setState,
    this.showLoginCallback,
    this.showMgwsUnavailableCallback,
  }) : desktopLayout = DockingLayout();

  final VoidCallback setState;
  final VoidCallback? showLoginCallback;

  /// Avviso mostrato quando una sezione MGWS-only viene richiesta senza
  /// backend disponibile. Riceve il motivo del fallimento perche' l'avviso
  /// distingua rete irraggiungibile, servizio spento e sessione assente.
  final void Function(MgwsUnavailableReason reason)?
  showMgwsUnavailableCallback;

  final DockingLayout desktopLayout;

  HomeTabMeta? _mobileEntry;
  Widget? _mobileContent;
  int _tabSequence = 0;
  bool _isChecking = true;
  UserGlobal? _currentUser;

  /// Unica fonte di verita: delega a `loginCode` (WooConnect).
  /// Tutte le card usano questo getter tramite `openSection(requiresAuth)`.
  bool get isConnected => loginCode.isConnected;

  /// True durante la verifica iniziale o il reload del profilo.
  bool get isChecking => _isChecking;

  /// Profilo WP corrente (nome + avatar), null se non autenticato.
  UserGlobal? get currentUser => _currentUser;

  String? get displayName => _currentUser?.displayName;

  String? get avatarUrl => _currentUser?.avatarUrl;

  String? get currentSiteUrl => loginCode.cachedSiteUrl;

  String _appVersionLabel = 'Versione non disponibile';

  String get appVersionLabel => _appVersionLabel;

  /// Etichetta build solo-debug (`(debug #N)`), null in release o senza define.
  /// Usata dalla Home per mostrare il badge visibile solo nelle prove locali.
  String? get debugBuildLabel {
    if (kDebugMode && _debugBuildNr.isNotEmpty) {
      return '(debug #$_debugBuildNr)';
    }
    return null;
  }

  HomeTabMeta? get mobileEntry => _mobileEntry;

  Widget? get mobileContent => _mobileContent;

  bool get isShowingMobileHome => _mobileEntry?.isHome ?? true;

  Future<void> checkAuthentication() async {
    _isChecking = true;
    _emit();
    try {
      await loadAppVersion();
      final success = await loginCode.tryAutoLogin();
      if (success) {
        final connectionWorking = await loginCode.testConnection();
        if (!connectionWorking) {
          await loginCode.logout();
        }
      }
      if (isConnected) {
        await _loadCurrentUser();
      } else {
        _currentUser = null;
      }
    } catch (_) {
      await loginCode.logout();
      _currentUser = null;
    } finally {
      _isChecking = false;
      _emit();
    }
  }

  /// Contatore incrementato a ogni avvio da `script/run_debug.sh` e passato
  /// via `--dart-define=DEBUG_BUILD_NR`. Esiste solo nelle compilazioni
  /// locali da codice: le release CI/GitHub non passano il define e hanno
  /// `kDebugMode` false, quindi non mostrano mai il suffisso debug.
  static const String _debugBuildNr = String.fromEnvironment('DEBUG_BUILD_NR');

  Future<void> loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersionLabel = 'Versione ${info.version}';
      if (kDebugMode && _debugBuildNr.isNotEmpty) {
        _appVersionLabel = '$_appVersionLabel (debug #$_debugBuildNr)';
      }
    } catch (_) {
      _appVersionLabel = 'Versione non disponibile';
    }
  }

  Future<void> onLoginSuccess() async {
    _emit();
    // Ordini e scorte si leggono solo con la sessione WooCommerce attiva.
    NotificationCenter.instance.refresh();
    await _loadCurrentUser();
    _emit();
  }

  Future<void> _loadCurrentUser() async {
    if (!isConnected) {
      _currentUser = null;
      return;
    }
    try {
      final profile = await loginCode.currentUserProfile();
      if (profile != null) {
        _currentUser = profile;
        return;
      }
      final fallbackName = await loginCode.loggedUsername();
      _currentUser = (fallbackName != null && fallbackName.trim().isNotEmpty)
          ? UserGlobal(username: fallbackName.trim(), name: fallbackName.trim())
          : null;
    } catch (_) {
      _currentUser = null;
    }
  }

  Future<void> logout() async {
    await loginCode.logout();
    _currentUser = null;
    NotificationCenter.instance.refresh();
    _emit();
  }

  void setHomePage({required String title, required Widget page}) {
    final homeMeta = HomeTabMeta(
      id: 'home',
      sectionId: 'home',
      baseTitle: title,
      isHome: true,
    );

    final homeItem = DockingItem(
      id: homeMeta.id,
      name: homeMeta.displayTitle,
      value: homeMeta,
      widget: KeyedSubtree(
        key: const ValueKey('home-docking-content'),
        child: page,
      ),
      closable: false,
      keepAlive: true,
    );

    // Use DockingTabs as root so it's always a DropArea (required by addItemOnRoot).
    // DockingRow/DockingColumn are NOT DropArea and would cause "Root is not a DropArea" errors.
    desktopLayout.root = DockingTabs([homeItem]);
    _mobileEntry = homeMeta;
    _mobileContent = page;
    _emit();
  }

  void openSection({
    required bool isSmallScreen,
    required String sectionId,
    required String title,
    required Widget page,
    required HomeTabOpenMode openMode,
    required bool requiresAuth,
    bool requiresMgws = false,
  }) {
    if (requiresAuth && !isConnected) {
      showLoginCallback?.call();
      return;
    }

    // Le sezioni MGWS-only si aprono solo con il backend disponibile: i loro
    // dati stanno nelle rotte MGWS, quindi aprirle senza backend mostrerebbe
    // una pagina vuota o errori a ogni azione. La verifica passa dallo stato
    // centralizzato, che usa il risultato della catena di login se esiste.
    if (requiresMgws) {
      _openMgwsSection(
        isSmallScreen: isSmallScreen,
        sectionId: sectionId,
        title: title,
        page: page,
        openMode: openMode,
      );
      return;
    }

    _openSectionTab(
      isSmallScreen: isSmallScreen,
      sectionId: sectionId,
      title: title,
      page: page,
      openMode: openMode,
    );
  }

  /// Verifica MGWS e apre la sezione solo se il backend e' utilizzabile.
  Future<void> _openMgwsSection({
    required bool isSmallScreen,
    required String sectionId,
    required String title,
    required Widget page,
    required HomeTabOpenMode openMode,
  }) async {
    try {
      final connected = await loginCode.ensureMgwsConnected();
      if (!connected) {
        showMgwsUnavailableCallback?.call(loginCode.mgwsConnection.lastFailure);
        return;
      }
    } catch (error, stack) {
      // La sezione resta chiusa: aprirela senza sapere se MGWS risponde
      // mostrerebbe una pagina vuota o errori a ogni azione.
      AppLogger().w(
        'Verifica MGWS fallita prima di aprire $sectionId: $error',
        null,
        stack,
      );
      showMgwsUnavailableCallback?.call(loginCode.mgwsConnection.lastFailure);
      return;
    }
    _openSectionTab(
      isSmallScreen: isSmallScreen,
      sectionId: sectionId,
      title: title,
      page: page,
      openMode: openMode,
    );
  }

  void _openSectionTab({
    required bool isSmallScreen,
    required String sectionId,
    required String title,
    required Widget page,
    required HomeTabOpenMode openMode,
  }) {
    if (isSmallScreen) {
      _mobileEntry = HomeTabMeta(
        id: '$sectionId-mobile',
        sectionId: sectionId,
        baseTitle: title,
        isHome: false,
      );
      _mobileContent = KeyedSubtree(
        key: ValueKey('${sectionId}-mobile-content'),
        child: page,
      );
      _emit();
      return;
    }

    if (openMode == HomeTabOpenMode.singleton) {
      final existingItem = _findSectionItem(sectionId);
      if (existingItem != null) {
        _focusItem(existingItem);
        _emit();
        return;
      }
    }

    // Il suffisso dell'istanza viene calcolato e conservato qui, una volta per
    // scheda, invece di ogni volta che il titolo viene ricostruito.
    final istanza = openMode == HomeTabOpenMode.singleton
        ? 0
        : _sectionInstanceCount(sectionId) + 1;

    final tabMeta = HomeTabMeta(
      id: _nextTabId(sectionId),
      sectionId: sectionId,
      baseTitle: title,
      isHome: false,
      istanza: istanza,
    );

    desktopLayout.addItemOnRoot(
      newItem: DockingItem(
        id: tabMeta.id,
        name: tabMeta.displayTitle,
        value: tabMeta,
        widget: KeyedSubtree(
          key: ValueKey('${tabMeta.id}-docking-content'),
          child: page,
        ),
        keepAlive: true,
      ),
      dropIndex: _rootDropIndex(),
    );
    final newItem = desktopLayout.findDockingItem(tabMeta.id);
    if (newItem != null) {
      _focusItem(newItem);
    }
    _emit();
  }

  void goHomeMobile() {
    final homeItem = desktopLayout.findDockingItem('home');
    if (homeItem == null) {
      return;
    }
    _mobileEntry = homeItem.value as HomeTabMeta?;
    _mobileContent = homeItem.widget;
    _emit();
  }

  void focusHomeDesktop() {
    final homeItem = desktopLayout.findDockingItem('home');
    if (homeItem == null) {
      return;
    }
    _focusItem(homeItem);
    _emit();
  }

  DockingItem? _findSectionItem(String sectionId) {
    for (final area in desktopLayout.layoutAreas()) {
      if (area is! DockingItem) {
        continue;
      }
      final meta = area.value as HomeTabMeta?;
      if (meta?.sectionId == sectionId) {
        return area;
      }
    }
    return null;
  }

  void _focusItem(DockingItem item) {
    final parentTabs = desktopLayout.findDockingTabsWithItem(item.id);
    if (parentTabs != null) {
      parentTabs.selectedIndex = parentTabs.indexOf(item);
      desktopLayout.rebuild();
    }
  }

  int _rootDropIndex() {
    final root = desktopLayout.root;
    if (root is DockingTabs) {
      return root.childrenCount;
    }
    return 1;
  }

  /// Quante schede della sezione sono gia aperte nel layout.
  int _sectionInstanceCount(String sectionId) {
    int count = 0;
    for (final area in desktopLayout.layoutAreas()) {
      if (area is! DockingItem) continue;
      final meta = area.value as HomeTabMeta?;
      if (meta?.sectionId == sectionId) count++;
    }
    return count;
  }

  /// Riallinea i titoli delle schede gia aperte con la lingua corrente.
  ///
  /// Il pacchetto docking legge l'etichetta di una scheda da
  /// [DockingItem.name], che e una stringa fissata quando la scheda viene
  /// aperta e non viene piu aggiornata da sola. [titoloSezione] risolve il
  /// titolo di una sezione dalla lingua corrente e restituisce `null` se la
  /// sezione non e piu disponibile, nel qual caso il titolo viene lasciato.
  ///
  /// Va chiamata mentre l'albero dei widget si sta ricostruendo: i nomi
  /// vengono riscritti sul posto e la ricostruzione in corso li rilegge
  /// nelle etichette, quindi non serve notificare il layout.
  void aggiornaTitoli({
    required String titoloHome,
    required String? Function(String sectionId) titoloSezione,
  }) {
    for (final area in desktopLayout.layoutAreas()) {
      if (area is! DockingItem) continue;
      final meta = area.value as HomeTabMeta?;
      if (meta == null) continue;

      final titolo = meta.isHome ? titoloHome : titoloSezione(meta.sectionId);
      if (titolo == null || titolo == meta.baseTitle) continue;

      meta.aggiornaTitolo(titolo);
      area.name = meta.displayTitle;
    }

    // Su mobile non c'e il layout docking: il titolo letto e quello mobile.
    final mobile = _mobileEntry;
    if (mobile != null && !mobile.isHome) {
      final titolo = titoloSezione(mobile.sectionId);
      if (titolo != null && titolo != mobile.baseTitle) {
        mobile.aggiornaTitolo(titolo);
      }
    }
  }

  String _nextTabId(String sectionId) {
    _tabSequence++;
    return '$sectionId-$_tabSequence';
  }

  void _emit() {
    notifyListeners();
    setState();
  }
}
