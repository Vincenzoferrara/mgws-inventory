import '../log_viewer/app_logger.dart';

/// Classe globale per rappresentare un utente con tutti i dati da WordPress
class UserGlobal {
  final int? id;
  final String? name;
  final String? username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? nickname;
  final String? description;
  final String? url;
  final String? link;
  final String? slug;
  final List<String>? roles;
  final DateTime? registeredDate;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? capabilities;
  final Map<String, dynamic>? avatarUrls;

  // Campi modificabili
  final String? password; // Per cambio password
  final bool? isActive; // Se attivo
  final Map<String, dynamic>? additionalMeta; // Meta aggiuntivi

  UserGlobal({
    this.id,
    this.name,
    this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.nickname,
    this.description,
    this.url,
    this.link,
    this.slug,
    this.roles,
    this.registeredDate,
    this.meta,
    this.capabilities,
    this.avatarUrls,
    this.password,
    this.isActive,
    this.additionalMeta,
  });

  /// Factory per creare UserGlobal dai dati WordPress (sanificati)
  factory UserGlobal.fromWordPressData(Map<String, dynamic> data) {
    try {
      return UserGlobal(
        id: data['id'] is int
            ? data['id']
            : int.tryParse(data['id']?.toString() ?? ''),
        name: data['name']?.toString(),
        username: data['username']?.toString(),
        email: data['email']?.toString(),
        firstName: data['first_name']?.toString(),
        lastName: data['last_name']?.toString(),
        nickname: data['nickname']?.toString(),
        description: data['description']?.toString(),
        url: data['url']?.toString(),
        link: data['link']?.toString(),
        slug: data['slug']?.toString(),
        roles: data['roles'] is List ? List<String>.from(data['roles']) : null,
        registeredDate: data['registered_date'] != null
            ? DateTime.tryParse(data['registered_date'].toString())
            : null,
        meta: data['meta'] is Map
            ? Map<String, dynamic>.from(data['meta'])
            : null,
        capabilities: data['capabilities'] is Map
            ? Map<String, dynamic>.from(data['capabilities'])
            : null,
        avatarUrls: data['avatar_urls'] is Map
            ? Map<String, dynamic>.from(data['avatar_urls'])
            : null,
        isActive: true, // Default attivo
      );
    } catch (e) {
      log.e('Errore in UserGlobal.fromWordPressData', e);
      rethrow;
    }
  }

  /// Converte UserGlobal in Map per salvataggio/modifica
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'nickname': nickname,
      'description': description,
      'url': url,
      'link': link,
      'slug': slug,
      'roles': roles,
      'registered_date': registeredDate?.toIso8601String(),
      'meta': meta,
      'capabilities': capabilities,
      'avatar_urls': avatarUrls,
    };
  }

  /// Metodo per visualizzare i dati principali
  String get displayName => name ?? username ?? 'Utente Sconosciuto';

  /// Metodo per ottenere l'avatar URL (se disponibile)
  String? get avatarUrl => avatarUrls?['96']; // 96x96

  /// Metodo per verificare se l'utente ha una capability
  bool hasCapability(String capability) {
    return capabilities?.containsKey(capability) ?? false;
  }

  /// Metodo per ottenere ruoli come stringa
  String get rolesString => roles?.join(', ') ?? 'Nessun ruolo';

  /// Metodo per copiare con modifiche (immutable)
  UserGlobal copyWith({
    int? id,
    String? name,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? nickname,
    String? description,
    String? url,
    String? link,
    String? slug,
    List<String>? roles,
    DateTime? registeredDate,
    Map<String, dynamic>? meta,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? avatarUrls,
    String? password,
    bool? isActive,
    Map<String, dynamic>? additionalMeta,
  }) {
    return UserGlobal(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      description: description ?? this.description,
      url: url ?? this.url,
      link: link ?? this.link,
      slug: slug ?? this.slug,
      roles: roles ?? this.roles,
      registeredDate: registeredDate ?? this.registeredDate,
      meta: meta ?? this.meta,
      capabilities: capabilities ?? this.capabilities,
      avatarUrls: avatarUrls ?? this.avatarUrls,
      password: password ?? this.password,
      isActive: isActive ?? this.isActive,
      additionalMeta: additionalMeta ?? this.additionalMeta,
    );
  }

  /// Metodo per validare i dati prima del salvataggio
  bool validate() {
    if (email != null && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email!)) {
      return false; // Email non valida
    }
    if (username != null && username!.isEmpty) {
      return false; // Username vuoto
    }
    return true;
  }

  /// Metodo per ottenere capabilities formattate
  String get capabilitiesString =>
      capabilities?.keys.join(', ') ?? 'Nessuna capability';

  /// Metodo per aggiornare meta
  UserGlobal updateMeta(String key, dynamic value) {
    final updatedMeta = Map<String, dynamic>.from(meta ?? {});
    updatedMeta[key] = value;
    return copyWith(meta: updatedMeta);
  }

  /// Sede di riferimento di questo utente, o zero se non ne ha una.
  ///
  /// Viene dal meta utente `mg_default_site_id` di WordPress, impostabile
  /// dall'amministratore nella pagina del profilo. Sul lato del plugin e' lo
  /// stesso valore che limita l'utente a una sola sede: chi lo ha, lavora su
  /// quella e non su altre, quindi i pannelli che scrivono lo stock possono
  /// partire gia' compilati e non lasciare scegliere una sede che il backend
  /// rifiuterebbe.
  ///
  /// Zero e' "nessuna sede", non "sedeGlobale": e' il valore con cui
  /// l'amministratore dice di poter lavorare ovunque, e in quel caso la scelta
  /// della sede spetta a chi opera.
  int get defaultSiteId {
    final raw = meta?['mg_default_site_id'];
    if (raw is int) return raw > 0 ? raw : 0;
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      return parsed != null && parsed > 0 ? parsed : 0;
    }
    return 0;
  }

  @override
  String toString() {
    return 'UserGlobal(id: $id, name: $name, email: $email, roles: $roles)';
  }
}
