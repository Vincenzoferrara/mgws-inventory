import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme_settings.gui.dart';
import 'prodotti_settings.gui.dart';
import 'ai_settings.gui.dart';
import 'cassa_settings.dart';
import 'cassa_settings.gui.dart';
import '../cassa/fiscal_register/fiscal_register_repository.dart';
import 'rfid_settings.gui.dart';
import 'shortcuts_settings.gui.dart';
import 'app_settings.dart';
import 'prodotti_image_settings.dart';
import 'general_settings.gui.dart';
import 'inventory_quick_load_settings.dart';
import 'inventory_settings.gui.dart';
import '../traduzioni/estensioni.dart';

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
        length: 8,
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
                // Futuro: Network, Logs, About...
                // Tab(icon: Icon(Icons.wifi), text: 'Network'),
                // Tab(icon: Icon(Icons.bug_report), text: 'Logs'),
                // Tab(icon: Icon(Icons.info), text: 'About'),
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
              // Futuro: altre tab
              // NetworkSettingsTab(),
              // LogsSettingsTab(),
              // AboutTab(),
            ],
          ),
        ),
      ),
    );
  }
}
