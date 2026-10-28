import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';

import '../../../reuse_class/logic/global_pagination_controller.dart';
import '../../../users/class_user_global.dart';
import '../woo_connect.dart';

/// Elenco degli utenti WordPress del negozio (`/wp/v2/users`).
///
/// Sola lettura: i permessi di un utente si gestiscono partendo dal
/// dipendente MGWS collegato (vedi `QueryUserWordPress`), non da qui.
class QueryUsersWordPress {
  static final QueryUsersWordPress _instance = QueryUsersWordPress._internal();
  factory QueryUsersWordPress() => _instance;
  QueryUsersWordPress._internal();

  WooCommerce get _woo => WooConnect().woo;

  /// Pagina di utenti con il totale letto da `X-WP-Total`.
  ///
  /// `context=edit` serve per email, ruoli e data di registrazione, che
  /// WordPress mostra solo a chi puo' gestire gli utenti. [roles] sono gli
  /// slug dei ruoli (`administrator`, `customer`, ...); [orderBy] un valore di
  /// `orderby` di WordPress (`name`, `email`, `registered_date`, `id`).
  Future<PaginatedResult<UserGlobal>> getUtentiPaginati({
    int page = 1,
    int perPage = 20,
    String? search,
    List<String>? roles,
    String orderBy = 'registered_date',
    bool ascending = false,
  }) async {
    final siteUrl = _woo.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _woo.dio.get(
      '$siteUrl/wp-json/wp/v2/users',
      queryParameters: {
        'context': 'edit',
        'page': page,
        'per_page': perPage,
        'orderby': orderBy,
        'order': ascending ? 'asc' : 'desc',
        if (search != null && search.isNotEmpty) 'search': search,
        if (roles != null && roles.isNotEmpty) 'roles': roles.join(','),
      },
    );
    final rows = response.data is List
        ? (response.data as List).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    return PaginatedResult<UserGlobal>(
      items: rows.map(UserGlobal.fromWordPressData).toList(),
      page: page,
      perPage: perPage,
      totalItems: int.tryParse(response.headers.value('x-wp-total') ?? ''),
      totalPages: int.tryParse(
        response.headers.value('x-wp-totalpages') ?? '',
      ),
    );
  }
}
