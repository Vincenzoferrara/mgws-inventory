import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme_settings.gui.dart';
import 'product_settings.gui.dart';
import 'ai_settings.gui.dart';
import 'checkout_settings.dart';
import 'checkout_settings.gui.dart';
import '../checkout/fiscal_register/fiscal_register_repository.dart';
import 'rfid_settings.gui.dart';
import 'shortcuts_settings.gui.dart';
import 'app_settings.dart';
import 'product_image_settings.dart';
import 'general_settings.gui.dart';
import 'inventory_quick_load_settings.dart';
import 'inventory_settings.gui.dart';
import 'about_settings.gui.dart';
import '../l10n/extensions.dart';

/// Pagina principale delle impostazioni con TabView
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  late AppSettings _appSettings;
  late ProductImageWarningSettings _productImageSettings;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    _appSettings = AppSettings();
    _productImageSettings = ProductImageWarningSettings();
    await Future.wait([
      _appSettings.init(),
      _productImageSettings.init(),
      inventoryQuickLoadSettings.init(),
      cassaSettings.init(),
      fiscalRegisterRepository.init(),
    ]);
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessario per AutomaticKeepAliveClientMixin
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: _appSettings),
        ChangeNotifierProvider<ProductImageWarningSettings>.value(
          value: _productImageSettings,
        ),
        ChangeNotifierProvider<InventoryQuickLoadSettings>.value(
          value: inventoryQuickLoadSettings,
        ),
      ],
      child: DefaultTabController(
        length: 9,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.settingsTitle),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  icon: const Icon(Icons.tune),
                  text: context.l10n.settingsTabGenerale,
                ),
                Tab(
                  icon: const Icon(Icons.warehouse_outlined),
                  text: context.l10n.settingsTabInventario,
                ),
                Tab(
                  icon: const Icon(Icons.inventory),
                  text: context.l10n.settingsTabProdotti,
                ),
                Tab(
                  icon: const Icon(Icons.point_of_sale),
                  text: context.l10n.settingsTabCassa,
                ),
                Tab(
                  icon: const Icon(Icons.palette),
                  text: context.l10n.settingsTabTema,
                ),
                Tab(
                  icon: const Icon(Icons.psychology),
                  text: context.l10n.settingsTabIa,
                ),
                Tab(
                  icon: const Icon(Icons.nfc),
                  text: context.l10n.settingsTabRfid,
                ),
                Tab(
                  icon: const Icon(Icons.keyboard),
                  text: context.l10n.settingsTabShortcut,
                ),
                Tab(
                  icon: const Icon(Icons.info_outline),
                  text: context.l10n.settingsTabInfo,
                ),
                // Futuro: Network, Logs...
                // Tab(icon: Icon(Icons.wifi), text: 'Network'),
                // Tab(icon: Icon(Icons.bug_report), text: 'Logs'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              GeneralSettingsTab(),
              InventorySettingsTab(),
              ProdottiSettingsTab(),
              CassaSettingsTab(),
              ThemeSettingsTab(),
              AISettingsTab(),
              RFIDSettingsTab(),
              ShortcutsSettingsTab(),
              AboutSettingsTab(),
              // Futuro: altre tab
              // NetworkSettingsTab(),
              // LogsSettingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}
