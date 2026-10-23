import 'package:flutter/material.dart';
import 'package:docking/docking.dart';

import '../l10n/extensions.dart';
import '../caldav/caldav_gui.dart';
import '../loyalty_cards/loyalty_cards.gui.dart';
import '../checkout/checkout.gui.dart';
import '../customers/customer_list.gui.dart';
import '../coupons/coupon_list/coupon_list_view.gui.dart';
import '../dashboard/dashboard_customization.dart';
import '../employees/employees.gui.dart';
import '../inventory/inventory.gui.dart';
import '../inventory/inventory_site_panel.gui.dart';
import '../inventory/inventory_suppliers.gui.dart';
import '../login/gui/login.gui.dart';
import '../login/mgws/connection/mgws_auth.dart';
import '../login/mgws/connection/mgws_connection.dart';
import '../login/mgws/query/query_mgws_site.dart';
import '../log_viewer/log_viewer.gui.dart';
import '../notification/notification_service.dart';
import '../orders/order_list/order_list.gui.dart';
import '../products/product_editor/product_editor.gui.dart';
import '../products/product_list/product_list.gui.dart';
import '../report/print_job.dart';
import '../report/report.gui.dart';
import '../settings/settings.gui.dart';
import '../theme/theme.dart';
import '../notification/notification_bell.gui.dart';
import '../notification/notification_center.dart';
import '../updater/updater.gui.dart';
import '../updater/updater_service.dart';
import 'home.code.dart';
import 'home_section_requests.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.startGuidedLogin = false});

  /// Requests the guided login once, right after the home is rendered.
  ///
  /// Set by the welcome flow, which has just explained the guides and sends the
  /// user straight into the first one. It is a request and not a mode: the home
  /// consumes it a single time and then forgets it, so a rebuild, a rotation or
  /// a layout change cannot open the login twice. Default `false` keeps every
  /// existing call site opening the home untouched.
  final bool startGuidedLogin;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeLogic _homeLogic;
  late final VoidCallback _desktopTabsListener;
  late List<_HomeSection> _sections;
  bool _isInitialized = false;

  /// Lingua per cui i titoli delle schede sono gia stati allineati.
  Locale? _ultimaLingua;

  @override
  void initState() {
    super.initState();
    _homeLogic = HomeLogic(
      setState: () => setState(() {}),
      showLoginCallback: _showLoginModal,
      showMgwsUnavailableCallback: _showMgwsUnavailable,
    );
    _desktopTabsListener = () => setState(() {});
    _homeLogic.desktopLayout.addListener(_desktopTabsListener);
    homeSectionRequest.addListener(_openRequestedSection);
    _initializeAuth();
    NotificationCenter.instance.start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showReleaseNotesAfterUpdate();
      await _notifyAvailableUpdate();
    });
  }

  Future<void> _initializeAuth() async {
    await _homeLogic.checkAuthentication();
    // Gli ordini e le scorte si possono leggere solo dopo il login.
    if (_homeLogic.isConnected) NotificationCenter.instance.refresh();
    if (_homeLogic.isConnected) await _verificaSede();
  }

  bool _verificaSedeInCorso = false;

  /// Dopo il login, con MGWS collegato, controlla che l'utente abbia una sede
  /// in uso. Se manca apre lo stesso pannello di Inventario: chi puo' crea o
  /// sceglie la sede, gli altri leggono a chi chiederla. La finestra si
  /// chiude da sola appena la sede c'e', e si puo' chiudere comunque: senza
  /// sede resta bloccato solo l'inventario, non il resto dell'app.
  Future<void> _verificaSede() async {
    if (_verificaSedeInCorso) return;
    _verificaSedeInCorso = true;
    try {
      if (!await MgwsConnection.instance.ensureConnected()) return;
      final MgwsSiteStatus stato;
      try {
        stato = await QueryMgwsSite().getMySite();
      } on MgwsSiteException {
        return;
      }
      if (stato.hasSite || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.sedeInUso),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: InventorySitePanel(
                onStatusChanged: (stato) {
                  if (stato != null) Navigator.of(dialogContext).pop();
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.commonClose),
            ),
          ],
        ),
      );
    } finally {
      _verificaSedeInCorso = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // L'elenco va ricalcolato per primo: il riallineamento dei titoli delle
    // schede lo usa come fonte per la lingua corrente.
    _sections = _buildSections(context);
    _allineaTitoliAllaLingua();
    if (!_isInitialized) {
      _homeLogic.setHomePage(
        title: context.l10n.homeTitoloHome,
        page: _buildHomeTabContent(),
      );
      _isInitialized = true;
    }
  }

  /// Riscrive i titoli delle schede gia aperte quando cambia la lingua.
  ///
  /// Le etichette delle tab del docking sono stringhe lette da
  /// `DockingItem.name`, non widget, quindi il cambio lingua non le aggiorna
  /// da solo. Il controllo evita di rifare il lavoro a ogni cambiamento di
  /// tema o di dimensione, che passano anch'essi da qui.
  void _allineaTitoliAllaLingua() {
    final lingua = Localizations.localeOf(context);
    if (_ultimaLingua == lingua) return;
    _ultimaLingua = lingua;

    _homeLogic.aggiornaTitoli(
      titoloHome: context.l10n.homeTitoloHome,
      titoloSezione: _titoloSezione,
    );
  }

  /// Titolo corrente di una sezione, o `null` se non e piu in elenco.
  String? _titoloSezione(String sectionId) {
    for (final section in _sections) {
      if (section.id == sectionId) return section.title;
    }
    return null;
  }

  @override
  void dispose() {
    _homeLogic.desktopLayout.removeListener(_desktopTabsListener);
    homeSectionRequest.removeListener(_openRequestedSection);
    NotificationCenter.instance.stop();
    super.dispose();
  }

  /// Elenco delle sezioni aperte dalla home.
  ///
  /// Riceve il `context` invece di usare quello dello stato, cosi le traduzioni
  /// lette qui vengono risolte con la lingua del widget che sta costruendo
  /// l'elenco. Passando il context dello stato le dipendenze cadrebbero sullo
  /// stato, che non viene ricostruito al cambio lingua.
  List<_HomeSection> _buildSections(BuildContext context) {
    final accents = context.accents;
    return [
      _HomeSection(
        id: 'cassa',
        title: context.l10n.homeTitoloCassa,
        subtitle: context.l10n.homeSottotitoloCassa,
        icon: Icons.point_of_sale,
        iconColor: accents.cassa,
        openMode: HomeTabOpenMode.singleton,
        requiresMgws: true,
        builder: () => const CassaPage(),
      ),
      _HomeSection(
        id: 'prodotti',
        title: context.l10n.homeTitoloProdotti,
        subtitle: context.l10n.homeSottotitoloProdotti,
        icon: Icons.shopping_cart,
        iconColor: accents.prodotti,
        openMode: HomeTabOpenMode.duplicate,
        builder: () => const ProdottiGestisciPage(),
      ),
      _HomeSection(
        id: 'inventario-mgws',
        title: context.l10n.homeTitoloInventarioMgws,
        subtitle: context.l10n.homeSottotitoloInventarioMgws,
        icon: Icons.inventory_2,
        iconColor: accents.inventario,
        openMode: HomeTabOpenMode.singleton,
        requiresAuth: false,
        requiresMgws: true,
        builder: () => const InventoryPage(),
      ),
      _HomeSection(
        id: 'nuovo-prodotto',
        title: context.l10n.homeTitoloNuovoProdotto,
        subtitle: context.l10n.homeSottotitoloNuovoProdotto,
        icon: Icons.add_circle,
        iconColor: accents.nuovoProdotto,
        openMode: HomeTabOpenMode.duplicate,
        builder: () => const ProdottiCreaPage(),
      ),
      _HomeSection(
        id: 'coupon',
        title: context.l10n.homeTitoloCoupon,
        subtitle: context.l10n.homeSottotitoloCoupon,
        icon: Icons.local_offer,
        iconColor: accents.coupon,
        openMode: HomeTabOpenMode.duplicate,
        builder: () => const CouponGestisciView(),
      ),
      _HomeSection(
        id: 'ordini',
        title: context.l10n.homeTitoloOrdini,
        subtitle: context.l10n.homeSottotitoloOrdini,
        icon: Icons.receipt_long,
        iconColor: accents.ordini,
        openMode: HomeTabOpenMode.duplicate,
        builder: () => const OrdiniGestisciPage(),
      ),
      _HomeSection(
        id: 'clienti',
        title: context.l10n.homeTitoloClienti,
        subtitle: context.l10n.homeSottotitoloClienti,
        icon: Icons.people,
        iconColor: accents.clienti,
        openMode: HomeTabOpenMode.duplicate,
        builder: () => const ClientiGestisciPage(),
      ),
      _HomeSection(
        id: 'fornitori',
        title: context.l10n.homeTitoloFornitori,
        subtitle: context.l10n.homeSottotitoloFornitori,
        icon: Icons.local_shipping,
        iconColor: accents.fornitori,
        openMode: HomeTabOpenMode.duplicate,
        requiresMgws: true,
        builder: () => InventorySupplierPanel(),
      ),
      _HomeSection(
        id: 'carte-fedelta',
        title: context.l10n.homeTitoloCarteFedelta,
        subtitle: context.l10n.homeSottotitoloCarteFedelta,
        icon: Icons.card_membership,
        iconColor: accents.carteFedelta,
        openMode: HomeTabOpenMode.singleton,
        requiresMgws: true,
        builder: () => const CartaFedeltaPage(),
      ),
      _HomeSection(
        id: printSectionId,
        title: context.l10n.homeTitoloReport,
        subtitle: context.l10n.homeSottotitoloReport,
        icon: Icons.print_outlined,
        iconColor: accents.report,
        openMode: HomeTabOpenMode.singleton,
        requiresMgws: true,
        builder: () => const PrintCenterPage(),
      ),
      _HomeSection(
        id: 'dashboard',
        title: context.l10n.homeTitoloDashboard,
        subtitle: context.l10n.homeSottotitoloDashboard,
        icon: Icons.assessment,
        iconColor: accents.dashboard,
        openMode: HomeTabOpenMode.singleton,
        requiresAuth: false,
        builder: () => const CustomizableDashboardPage(),
      ),
      _HomeSection(
        id: 'impostazioni',
        title: context.l10n.homeTitoloImpostazioni,
        subtitle: context.l10n.homeSottotitoloImpostazioni,
        icon: Icons.settings,
        iconColor: accents.impostazioni,
        openMode: HomeTabOpenMode.singleton,
        requiresAuth: false,
        builder: () => const SettingsPage(),
      ),
      _HomeSection(
        id: 'aggiornamenti',
        title: context.l10n.homeTitoloAggiornamenti,
        subtitle: context.l10n.homeSottotitoloAggiornamenti,
        icon: Icons.system_update,
        iconColor: accents.aggiornamenti,
        openMode: HomeTabOpenMode.singleton,
        requiresAuth: false,
        builder: () => const UpdaterPage(),
      ),
      _HomeSection(
        id: 'caldav',
        title: context.l10n.homeTitoloCaldav,
        subtitle: context.l10n.homeSottotitoloCaldav,
        icon: Icons.calendar_today,
        iconColor: accents.caldav,
        openMode: HomeTabOpenMode.singleton,
        builder: () => const CalDavGui(),
      ),
      _HomeSection(
        id: 'dipendenti',
        title: context.l10n.homeTitoloDipendenti,
        subtitle: context.l10n.homeSottotitoloDipendenti,
        icon: Icons.work,
        iconColor: accents.dipendenti,
        openMode: HomeTabOpenMode.singleton,
        requiresMgws: true,
        builder: () => const DipendentiGui(),
      ),
    ];
  }

  Widget _buildHomeTabContent() {
    return _HomeLandingPage(
      homeLogic: _homeLogic,
      // La lista viene richiesta in fase di build e non passata come valore.
      // La home resta nel docking layout per tutta la sessione: una lista
      // catturata qui manterrebbe i titoli della lingua del primo avvio anche
      // dopo un cambio lingua.
      sectionsBuilder: _buildSections,
      onOpenSection: _openSection,
      onShowLogin: _showLoginModal,
    );
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < homeSmallScreenBreakpoint;
  }

  void _openSection(_HomeSection section) {
    _homeLogic.openSection(
      isSmallScreen: _isSmallScreen(context),
      sectionId: section.id,
      title: section.title,
      page: section.builder(),
      openMode: section.openMode,
      requiresAuth: section.requiresAuth,
      requiresMgws: section.requiresMgws,
    );
  }

  /// Apre la sezione chiesta da un'altra sezione tramite [requestHomeSection].
  void _openRequestedSection() {
    final sectionId = homeSectionRequest.value;
    if (sectionId == null || !mounted) return;
    homeSectionRequest.value = null;
    _openSectionById(sectionId);
  }

  /// Apre una sezione dal suo id, es. da una notifica della campanella.
  void _openSectionById(String sectionId) {
    final section = _sections
        .where((section) => section.id == sectionId)
        .firstOrNull;
    if (section != null) _openSection(section);
  }

  void _showLoginModal() {
    if (_isSmallScreen(context)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.homeAutenticazioneRichiesta),
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            body: _buildLoginContent(context),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.homeAutenticazioneRichiesta,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildLoginContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// Avviso per una sezione MGWS-only richiesta senza backend disponibile.
  ///
  /// Il testo distingue il motivo: rete irraggiungibile, servizio MGWS spento
  /// e sessione WordPress assente indicano interventi diversi. La sezione
  /// richiesta non viene aperta, quindi l'utente resta sulla home.
  void _showMgwsUnavailable(MgwsUnavailableReason reason) {
    // La chiamata arriva dopo un await di rete: la home puo' essere stata
    // smontata nel frattempo, e usare il context per mostrare il dialog
    // lancerebbe. Senza dialog l'utente resta semplicemente sulla home.
    if (!mounted) return;
    final l10n = context.l10n;
    final String messaggio;
    switch (reason) {
      case MgwsUnavailableReason.noSession:
        messaggio = l10n.mgwsNonDisponibileMessaggio;
      case MgwsUnavailableReason.unreachable:
        messaggio = l10n.mgwsNonRaggiungibile;
      case MgwsUnavailableReason.serviceDisabled:
        messaggio = l10n.mgwsServizioSpento;
      case MgwsUnavailableReason.pluginOutdated:
        messaggio = l10n.mgwsPluginDaAggiornare(
          MgwsConnection.instance.pluginVersion ?? '?',
          MgwsAuth.minPluginVersion,
        );
      case MgwsUnavailableReason.unknown:
        messaggio = l10n.mgwsNonDisponibileMessaggio;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.cloud_off,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: Text(l10n.mgwsNonDisponibileTitolo),
        content: Text(messaggio),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.mgwsHoCapito),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginContent(BuildContext context) {
    final customColors = Theme.of(context).extension<AppColorExtension>()!;

    return Padding(
      padding: EdgeInsets.all(_isSmallScreen(context) ? 16 : 0),
      child: Column(
        children: [
          if (!_homeLogic.isConnected)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: customColors.warningColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: customColors.warningColor.withValues(alpha: 0.3),
                ),
                borderRadius: context.shapes.s,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: customColors.warningColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.homeLoginRichiestoMessaggio,
                      style: TextStyle(color: customColors.warningColor),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: LoginPage(
              onLoginSuccess: () {
                Navigator.of(context).pop();
                _homeLogic.onLoginSuccess();
                NotificationService.instance.messageBar(
                  'successo',
                  'home',
                  context.l10n.homeLoginSuccesso,
                );
                _verificaSede();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.headerGradientStart,
                  context.colors.headerGradientEnd,
                ],
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Icon(
                      Icons.store,
                      size: 30,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.homeTitoloDrawer,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _homeLogic.isConnected
                        ? context.l10n.homeStatoAutenticatoBreve
                        : context.l10n.homeStatoNonAutenticatoBreve,
                    style: context.text.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  title: context.l10n.homeTitoloHome,
                  onTap: () {
                    Navigator.pop(context);
                    if (_isSmallScreen(context)) {
                      _homeLogic.goHomeMobile();
                    } else {
                      _homeLogic.focusHomeDesktop();
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.login,
                  title: context.l10n.homeTitoloLogin,
                  onTap: () {
                    Navigator.pop(context);
                    _showLoginModal();
                  },
                ),
                const Divider(),
                for (final section in _sections)
                  _buildDrawerItem(
                    icon: section.icon,
                    title: section.title,
                    onTap: () {
                      Navigator.pop(context);
                      _openSection(section);
                    },
                  ),
                if (_homeLogic.isConnected) ...[
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: context.l10n.homeTitoloLogout,
                    onTap: () async {
                      Navigator.pop(context);
                      await _homeLogic.logout();
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: context.spacing.iL,
            child: Text(
              _homeLogic.appVersionLabel(context.l10n),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  /// Bottone log riusato dalla vecchia home (bug_report rosso su cerchio nero).
  Widget _buildLogButton() {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariantColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.bug_report,
          color: context.colors.errorColorStatus,
          size: 20,
        ),
      ),
      tooltip: context.l10n.homeTooltipVisualizzaLog,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const LogViewerScreen()),
        );
      },
    );
  }

  /// Stato login in fondo a destra: avatar WP + nome + status, menu logout.
  Widget _buildAuthAction() {
    final customColors = Theme.of(context).extension<AppColorExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_homeLogic.isChecking) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.onPrimary,
                ),
              ),
            ),
            Text(
              context.l10n.homeVerificaInCorso,
              style: context.text.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (!_homeLogic.isConnected) {
      return FilledButton.tonalIcon(
        onPressed: _showLoginModal,
        icon: const Icon(Icons.login, size: 18),
        label: Text(context.l10n.homeTitoloLogin),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: context.shapes.full),
        ),
      );
    }

    final avatarUrl = _homeLogic.avatarUrl;
    final displayName =
        _homeLogic.displayName ?? context.l10n.homeNomeUtentePredefinito;
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      tooltip: context.l10n.homeTooltipAccount,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: customColors.successColor.withValues(alpha: 0.15),
          borderRadius: context.shapes.xl,
          border: Border.all(
            color: customColors.successColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: customColors.successColor,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              onBackgroundImageError: avatarUrl != null ? (_, __) {} : null,
              child: avatarUrl == null
                  ? Icon(Icons.person, size: 16, color: colorScheme.onPrimary)
                  : null,
            ),
            const SizedBox(width: 8),
            if (_isSmallScreen(context))
              // Su smartphone il nome utente troncava il titolo in AppBar:
              // solo pallino di stato, il nome resta nel menu account.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: customColors.successColor,
                  shape: BoxShape.circle,
                ),
              )
            else ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  Text(
                    '● Online',
                    style: context.text.bodySmall?.copyWith(
                      color: customColors.successColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.arrow_drop_down, color: colorScheme.onPrimary, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.homeStatoConnesso),
                  if (_homeLogic.currentSiteUrl != null)
                    Text(
                      _homeLogic.currentSiteUrl!,
                      style: context.text.bodySmall?.copyWith(
                        color: customColors.subtitleColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 16,
                color: customColors.errorColorStatus,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.homeTitoloLogout,
                style: TextStyle(color: customColors.errorColorStatus),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.homeConfermaLogoutTitolo),
              content: Text(context.l10n.homeConfermaLogoutTesto),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.homeTitoloLogout),
                ),
              ],
            ),
          );
          if (shouldLogout == true) {
            await _homeLogic.logout();
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = _isSmallScreen(context);
    final showMobileBack = isSmallScreen && !_homeLogic.isShowingMobileHome;
    final appBarTitle = showMobileBack
        ? (_homeLogic.mobileEntry?.displayTitle ??
              context.l10n.homeTitoloMobileBack)
        : context.l10n.homeTitoloDesktop;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        automaticallyImplyLeading: !showMobileBack,
        leading: showMobileBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _homeLogic.goHomeMobile,
              )
            : null,
        actions: [
          NotificationBell(
            compact: isSmallScreen,
            onOpenSection: _openSectionById,
          ),
          _buildLogButton(),
          _buildAuthAction(),
          const SizedBox(width: 8),
        ],
      ),
      drawer: showMobileBack ? null : _buildDrawer(),
      body: isSmallScreen
          ? (_homeLogic.mobileContent ?? const SizedBox.shrink())
          : MultiSplitViewTheme(
              data: _buildMultiSplitTheme(theme),
              child: TabbedViewTheme(
                data: _buildTabbedViewTheme(theme),
                child: Docking(
                  layout: _homeLogic.desktopLayout,
                  draggable: true,
                  maximizableItem: true,
                  maximizableTab: true,
                  maximizableTabsArea: true,
                ),
              ),
            ),
    );
  }

  MultiSplitViewThemeData _buildMultiSplitTheme(ThemeData theme) {
    return MultiSplitViewThemeData(
      dividerThickness: 8,
      dividerPainter: DividerPainters.grooved1(
        color: theme.colorScheme.outlineVariant,
        highlightedColor: theme.primaryColor,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  TabbedViewThemeData _buildTabbedViewTheme(ThemeData theme) {
    return TabbedViewThemeData(
      tab: TabThemeData(
        textStyle:
            theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ) ??
            // Fallback solo se il tema non definisce titleSmall: senza
            // fontSize esplicito il testo eredita la dimensione predefinita.
            TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.outline.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.3 : 0.2,
              ),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        normalButtonColor: theme.colorScheme.onSurfaceVariant,
        hoverButtonColor: theme.colorScheme.onSurface,
        closeIcon: IconProvider.data(Icons.close),
        selectedStatus: TabStatusThemeData(
          decoration: BoxDecoration(
            color: theme.primaryColor,
            border: Border(
              right: BorderSide(color: theme.primaryColor, width: 1),
            ),
          ),
          fontColor: theme.colorScheme.onPrimary,
          normalButtonColor: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
          hoverButtonColor: theme.colorScheme.onPrimary,
        ),
        highlightedStatus: TabStatusThemeData(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outline.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.3 : 0.2,
                ),
                width: 1,
              ),
            ),
          ),
        ),
      ),
      tabsArea: TabsAreaThemeData(
        color: theme.colorScheme.surface,
        buttonsAreaDecoration: BoxDecoration(color: theme.colorScheme.surface),
      ),
      contentArea: ContentAreaThemeData(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      ),
    )..materialDesignIcons();
  }

  /// Avvisa una sola volta per release che esiste una versione nuova.
  ///
  /// Su desktop l'azione apre la sezione Aggiornamenti, dove Velopack
  /// installa; su Android resta un avviso, perche l'aggiornamento arriva da
  /// F-Droid, Obtainium o dallo store.
  Future<void> _notifyAvailableUpdate() async {
    final version = await UpdaterService().pendingUpdateNotice();
    if (!mounted || version == null) return;

    final l10n = context.l10n;
    final notifyOnly = UpdaterService.isNotifyOnlyPlatform;
    final updaterSection = _sections
        .where((section) => section.id == 'aggiornamenti')
        .firstOrNull;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notifyOnly
              ? l10n.updaterUpdateAvailableNotifyOnlyMessage(version)
              : l10n.homeAggiornamentoDisponibile(version),
        ),
        duration: Duration(seconds: notifyOnly ? 8 : 10),
        action: notifyOnly || updaterSection == null
            ? null
            : SnackBarAction(
                label: l10n.homeApriAggiornamenti,
                onPressed: () => _openSection(updaterSection),
              ),
      ),
    );
  }

  Future<void> _showReleaseNotesAfterUpdate() async {
    final notes = await UpdaterService().releaseNotesForInstalledUpdate();
    if (!mounted || notes == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          notes.title.isEmpty
              ? context.l10n.homeReleaseNoteTitolo(notes.version)
              : notes.title,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
          child: SingleChildScrollView(
            child: SelectableText(
              notes.body.isEmpty
                  ? context.l10n.homeReleaseNoteVuota
                  : notes.body,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.homeChiudi),
          ),
        ],
      ),
    );
  }
}

class _HomeSection {
  const _HomeSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.openMode,
    required this.builder,
    this.requiresAuth = true,
    this.requiresMgws = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final HomeTabOpenMode openMode;
  final bool requiresAuth;

  /// La sezione funziona solo con il backend MGWS disponibile.
  ///
  /// Vale per cassa, fornitori, inventario MGWS, carte fedelta' e dipendenti:
  /// i loro dati stanno nelle rotte MGWS, quindi senza backend la sezione si
  /// aprirebbe vuota o mostrerebbe errori a ogni azione. Le sezioni che leggono
  /// da WooCommerce restano apribili e degradano da sole.
  final bool requiresMgws;

  final Widget Function() builder;
}

class _HomeLandingPage extends StatelessWidget {
  const _HomeLandingPage({
    required this.homeLogic,
    required this.sectionsBuilder,
    required this.onOpenSection,
    required this.onShowLogin,
  });

  final HomeLogic homeLogic;

  /// Costruisce l'elenco delle sezioni al momento del build.
  ///
  /// Va chiamato con il `context` di questo widget: e' la lettura di
  /// `context.l10n` dentro il builder a far dipendere questa pagina dalla
  /// lingua, quindi un cambio lingua la ricostruisce con i titoli nuovi.
  final List<_HomeSection> Function(BuildContext context) sectionsBuilder;

  final ValueChanged<_HomeSection> onOpenSection;
  final VoidCallback onShowLogin;

  @override
  Widget build(BuildContext context) {
    // L'elenco e' costruito qui, con il context di questo widget, e non
    // dentro l'AnimatedBuilder: cosi' la lettura delle traduzioni registra la
    // dipendenza su questa pagina e il cambio lingua la ricostruisce.
    final sections = sectionsBuilder(context);

    return AnimatedBuilder(
      animation: homeLogic,
      builder: (context, _) {
        final theme = Theme.of(context);
        final customColors = theme.extension<AppColorExtension>();
        final colorScheme = theme.colorScheme;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _landingGradientColors(theme, customColors),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          borderRadius: context.shapes.xl,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.surface.withValues(alpha: 0.92),
                              colorScheme.primaryContainer.withValues(
                                alpha: 0.38,
                              ),
                              (customColors?.variantSelectedBackground ??
                                      colorScheme.surfaceContainerHighest)
                                  .withValues(alpha: 0.42),
                            ],
                          ),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.10),
                              blurRadius: 34,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 720;
                            final heroIcon = Container(
                              width: isCompact ? 76 : 92,
                              height: isCompact ? 76 : 92,
                              decoration: BoxDecoration(
                                borderRadius: context.shapes.xl,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    context.colors.headerGradientStart,
                                    context.colors.headerGradientEnd,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 22,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.store,
                                size: isCompact ? 36 : 44,
                                color: colorScheme.onPrimary,
                              ),
                            );
                            final heroCopy = Column(
                              crossAxisAlignment: isCompact
                                  ? CrossAxisAlignment.center
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.homeBenvenutoTitolo,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.onSurface,
                                        letterSpacing: -0.4,
                                      ),
                                  textAlign: isCompact
                                      ? TextAlign.center
                                      : TextAlign.start,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  context.l10n.homeBenvenutoSottotitolo,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color:
                                        customColors?.subtitleColor ??
                                        colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: isCompact
                                      ? TextAlign.center
                                      : TextAlign.start,
                                ),
                              ],
                            );

                            if (isCompact) {
                              return Column(
                                children: [
                                  heroIcon,
                                  const SizedBox(height: 22),
                                  heroCopy,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                heroIcon,
                                const SizedBox(width: 24),
                                Expanded(child: heroCopy),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildAuthStatusCard(context),
                      if (homeLogic.debugBuildLabel != null) ...[
                        const SizedBox(height: 12),
                        _buildDebugBadge(context),
                      ],
                      const SizedBox(height: 28),
                      _buildQuickActionCards(context, sections),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Color> _landingGradientColors(
    ThemeData theme,
    AppColorExtension? customColors,
  ) {
    if (customColors != null) {
      return [customColors.gradientStart, customColors.gradientEnd];
    }

    return theme.brightness == Brightness.dark
        ? [AppTheme.darkGradientStart, AppTheme.darkGradientEnd]
        : [AppTheme.lightGradientStart, AppTheme.lightGradientEnd];
  }

  int _quickActionColumnCount(double maxWidth) {
    if (maxWidth < 620) return 1;
    if (maxWidth < 900) return 2;
    if (maxWidth < 1160) return 3;
    return 4;
  }

  Widget _buildAuthStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final customColors = theme.extension<AppColorExtension>()!;
    final isConnected = homeLogic.isConnected;

    final statusColor = isConnected
        ? customColors.successColor
        : customColors.errorColorStatus;
    final statusIcon = isConnected ? Icons.check_circle : Icons.error;
    final statusText = isConnected
        ? context.l10n.homeStatoAutenticato
        : context.l10n.homeStatoNonAutenticato;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: context.shapes.xl,
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: context.shapes.full,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isConnected)
                FilledButton.tonalIcon(
                  onPressed: onShowLogin,
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(context.l10n.homeTitoloLogin),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: context.shapes.full,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Badge visibile solo nelle build debug locali (`kDebugMode` + define
  /// passato da `script/run_debug.sh`). In release non viene mai costruito.
  Widget _buildDebugBadge(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final label = homeLogic.debugBuildLabel ?? '';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: customColors.warningColor.withValues(alpha: 0.12),
          borderRadius: context.shapes.full,
          border: Border.all(
            color: customColors.warningColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report, size: 16, color: customColors.warningColor),
            const SizedBox(width: 6),
            Text(
              context.l10n.homeBuildLocale(label),
              style: theme.textTheme.labelMedium?.copyWith(
                color: customColors.warningColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCards(
    BuildContext context,
    List<_HomeSection> sections,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 18.0;
        final columns = _quickActionColumnCount(constraints.maxWidth);
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final section in sections)
              _buildQuickActionCard(
                context,
                section: section,
                width: cardWidth,
                onTap: () => onOpenSection(section),
              ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required _HomeSection section,
    required double width,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final customColors = theme.extension<AppColorExtension>()!;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: context.shapes.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.shapes.xl,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: context.shapes.xl,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface.withValues(alpha: 0.94),
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.68),
                ],
              ),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: section.iconColor.withValues(alpha: 0.14),
                          borderRadius: context.shapes.xl,
                          border: Border.all(
                            color: section.iconColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          section.icon,
                          size: 28,
                          color: section.iconColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    section.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: customColors.subtitleColor,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
