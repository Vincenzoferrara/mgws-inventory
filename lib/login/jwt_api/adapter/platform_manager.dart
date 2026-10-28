import '../query_woocommerce/woo_query_products.dart';
import '../query_woocommerce/woo_query_categories.dart';
import '../query_woocommerce/woo_query_tag.dart';
import '../query_woocommerce/woo_query_coupon.dart';
import '../query_woocommerce/woo_query_customers.dart';
import '../query_woocommerce/woo_query_orders.dart';
import '../query_woocommerce/woo_query_variations.dart';
import '../query_woocommerce/woo_query_attributes.dart';
import '../query_woocommerce/woo_query_media.dart';
import '../query_woocommerce/woo_query_report.dart';
import '../query_woocommerce/woo_query_batch.dart';
import '../query_woocommerce/woo_query_brands.dart';
import '../../mgws/query/query_mgws_pos.dart';
import '../../mgws/query/query_mgws_employees.dart';
import '../../mgws/query/query_mgws_user_settings.dart';
import '../../mgws/query/query_mgws_dashboards.dart';
import '../../mgws/query/query_mgws_reports.dart';
import '../../mgws/connection/mgws_auth.dart';
import '../../mgws/connection/mgws_connection.dart';
import '../query_wordpress/query_user_wordpress.dart';
import '../query_wordpress/query_users_wordpress.dart';
import '../woo_connect.dart';
import 'loyalty_gateway.dart';

/// Manager centrale per il perimetro WordPress ammesso dall'app.
///
/// L'app consuma WooCommerce direttamente per le sue API e MGWS per funzioni
/// native custom come loyalty e inventario. Non sono previsti provider esterni
/// o failback lato app.
class PlatformManager {
  // Istanze singleton delle query (lazy initialization)
  static WooQueryProdotti? _wooProdotti;
  static WooQueryCategoria? _wooCategorie;
  static WooQueryTag? _wooTag;
  static WooQueryCoupon? _wooCoupon;
  static WooQueryClienti? _wooClienti;
  static WooQueryOrdini? _wooOrdini;
  static WooQueryVarianti? _wooVarianti;
  static WooQueryAttributi? _wooAttributi;
  static WooQueryMedia? _wooMedia;
  static WooQueryReport? _wooReport;
  static WooQueryBatch? _wooBatch;
  static WooQueryMarchi? _wooMarchi;
  static LoyaltyGateway? _loyaltyGateway;
  static QueryMgwsPos? _mgwsPos;
  static QueryMgwsEmployees? _mgwsEmployees;
  static QueryMgwsUserSettings? _mgwsUserSettings;
  static QueryMgwsDashboards? _mgwsDashboards;
  static QueryMgwsReports? _mgwsReports;
  static QueryUserWordPress? _permessiUtente;
  static QueryUsersWordPress? _utenti;

  /// Ottiene la piattaforma attualmente attiva
  static PlatformType get currentPlatform => PlatformType.woocommerce;

  /// Nome della piattaforma corrente
  static String get platformName => PlatformType.woocommerce.name;

  /// Verifica se la connessione è pronta
  static bool get isReady => WooConnect().isReady;

  /// Stato centralizzato della disponibilità del backend MGWS.
  static bool get isMgwsAvailable => MgwsConnection.instance.isConnected;

  /// MGWS è utilizzabile solo quando esistono sia sessione Woo sia backend MGWS.
  static bool get canUseMgws => isReady && isMgwsAvailable;

  /// Riesegue la verifica centralizzata dei servizi MGWS.
  static Future<bool> refreshMgwsAvailability() =>
      MgwsConnection.instance.verify();

  /// Garantisce che lo stato MGWS sia noto e restituisce se è utilizzabile.
  ///
  /// È il metodo da usare nei moduli: usa la verifica della catena di login
  /// se esiste, altrimenti verifica adesso.
  static Future<bool> ensureCanUseMgws() async {
    if (!isReady) {
      MgwsConnection.instance.markDisconnected(
        reason: MgwsUnavailableReason.noSession,
      );
      return false;
    }
    return await MgwsConnection.instance.ensureConnected();
  }

  /// Riesegue la verifica e ritorna lo stato effettivamente utilizzabile.
  ///
  /// Forza il colpo di rete: va usata solo per azioni che richiedono uno stato
  /// fresco, come un checkout o un'azione esplicita dell'utente.
  static Future<bool> refreshCanUseMgws() async {
    if (!isReady) {
      MgwsConnection.instance.markDisconnected(
        reason: MgwsUnavailableReason.noSession,
      );
      return false;
    }
    return await MgwsConnection.instance.verify();
  }

  /// Compatibilita API: l'unica piattaforma ammessa lato app e WooCommerce.
  static void setPlatform(PlatformType platform) {}

  /// Reset alla piattaforma predefinita (WooCommerce)
  static void reset() {}

  // =========================================================================
  // ==                         QUERY ACCESSORS                             ==
  // =========================================================================

  /// Query Prodotti per la piattaforma corrente
  static dynamic get prodotti {
    _wooProdotti ??= WooQueryProdotti();
    return _wooProdotti;
  }

  /// Query Categorie per la piattaforma corrente
  static dynamic get categorie {
    _wooCategorie ??= WooQueryCategoria();
    return _wooCategorie;
  }

  /// Query Tag per la piattaforma corrente
  static dynamic get tag {
    _wooTag ??= WooQueryTag();
    return _wooTag;
  }

  /// Query Marchi per la piattaforma corrente
  static dynamic get marchi {
    _wooMarchi ??= WooQueryMarchi();
    return _wooMarchi;
  }

  /// Query Coupon per la piattaforma corrente
  static dynamic get coupon {
    _wooCoupon ??= WooQueryCoupon();
    return _wooCoupon;
  }

  /// Query Clienti per la piattaforma corrente
  static dynamic get clienti {
    _wooClienti ??= WooQueryClienti();
    return _wooClienti;
  }

  /// Elenco utenti WordPress del negozio, in sola lettura.
  static QueryUsersWordPress get utenti {
    _utenti ??= QueryUsersWordPress();
    return _utenti!;
  }

  /// Query Ordini per la piattaforma corrente
  static dynamic get ordini {
    _wooOrdini ??= WooQueryOrdini();
    return _wooOrdini;
  }

  /// Query Varianti per la piattaforma corrente
  static dynamic get varianti {
    _wooVarianti ??= WooQueryVarianti();
    return _wooVarianti;
  }

  /// Query Attributi per la piattaforma corrente
  static dynamic get attributi {
    _wooAttributi ??= WooQueryAttributi();
    return _wooAttributi;
  }

  /// Query Media per la piattaforma corrente
  static dynamic get media {
    _wooMedia ??= WooQueryMedia();
    return _wooMedia;
  }

  /// Query Report per la piattaforma corrente
  static dynamic get report {
    _wooReport ??= WooQueryReport();
    return _wooReport;
  }

  /// Query Batch per la piattaforma corrente
  static dynamic get batch {
    _wooBatch ??= WooQueryBatch();
    return _wooBatch;
  }

  // =========================================================================
  // ==                         METADATA HELPERS                             ==
  // =========================================================================

  /// Aggiorna i metadata di un prodotto
  static Future<bool> updateProductMetadata(
    int productId,
    Map<String, dynamic> metadata,
  ) async {
    final prodotti = PlatformManager.prodotti;
    return await prodotti.updateProductMetadata(productId, metadata);
  }

  /// Recupera i metadata di un prodotto
  static Future<Map<String, String>> getProductMetadata(int productId) async {
    final prodotti = PlatformManager.prodotti;
    return await prodotti.getProductMetadata(productId);
  }

  /// Recupera i metadata di una variante prodotto per la piattaforma corrente
  static Future<Map<String, String>> getProductVariationMetadata(
    int productId,
    int variationId,
  ) async {
    final varianti = PlatformManager.varianti;
    return await varianti.getProductVariationMetadata(productId, variationId);
  }

  /// Query Carta Fedeltà via MGWS per la piattaforma corrente
  static dynamic get cartaFedelta {
    _loyaltyGateway ??= LoyaltyGateway();
    return _loyaltyGateway;
  }

  /// Checkout POS via MGWS.
  static dynamic get pos {
    _mgwsPos ??= QueryMgwsPos();
    return _mgwsPos;
  }

  /// Dipendenti via MGWS.
  static dynamic get dipendenti {
    _mgwsEmployees ??= QueryMgwsEmployees();
    return _mgwsEmployees;
  }

  /// Impostazioni utente/app sincronizzate via MGWS.
  static dynamic get userSettings {
    _mgwsUserSettings ??= QueryMgwsUserSettings();
    return _mgwsUserSettings;
  }

  /// Personal and shared dashboards stored in MGWS.
  static QueryMgwsDashboards get dashboards {
    _mgwsDashboards ??= QueryMgwsDashboards();
    return _mgwsDashboards!;
  }

  /// MGWS report engine: measures split by dimensions, aggregated server-side.
  static QueryMgwsReports get reports {
    _mgwsReports ??= QueryMgwsReports();
    return _mgwsReports!;
  }

  /// Username dell'utente autenticato, se noto. La cassa lo usa come
  /// operatore perche l'utente loggato e l'utente che usa la cassa.
  static Future<String?> loggedUsername() => WooConnect().loggedUsername();

  // =========================================================================
  // ==                  PERMESSI UTENTE DIPENDENTE                         ==
  // =========================================================================

  /// Permessi WordPress/MGWS di un dipendente collegato a `wp_user_id`.
  ///
  /// Non espone una lista utenti generica: i permessi si gestiscono solo
  /// partendo da un dipendente MGWS, mai per utenti non dipendenti.
  static dynamic get permessiUtente {
    _permessiUtente ??= QueryUserWordPress();
    return _permessiUtente;
  }
}

/// Enum per le piattaforme e-commerce supportate
enum PlatformType { woocommerce }
