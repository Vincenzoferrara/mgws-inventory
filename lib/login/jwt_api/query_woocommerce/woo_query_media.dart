import 'dart:io';
import '../woo_connect.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../error_list.dart';
import '../../../products/class_media.dart';
import '../../../log_viewer/app_logger.dart';

/// Query class per gestione media/file WordPress
/// Utilizza WooConnect per l'autenticazione centralizzata
/// Nota: Usa Dio diretto perché Media usa WordPress API (/wp/v2/media), non WooCommerce API
class WooQueryMedia {
  // Singleton pattern
  static final WooQueryMedia _instance = WooQueryMedia._internal();
  factory WooQueryMedia() => _instance;
  WooQueryMedia._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  get _woo => _wooConnect.woo;

  /// Upload file media (immagine)
  Future<MediaFile> uploadMedia(
    String filePath, {
    String? title,
    String? altText,
    String? caption,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw LocalizedException(
          'File not found: $filePath',
          (l10n) => l10n.mediaFileNotFound(filePath),
        );
      }

      // Determina content type dal file
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final contentType = _getContentType(extension);

      // Crea FormData per upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
        if (title != null) 'title': title,
        if (altText != null) 'alt_text': altText,
        if (caption != null) 'caption': caption,
      });

      final response = await _woo.dio.post(
        '${_wooConnect.siteUrl}/wp-json/wp/v2/media',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      final data = response.data as Map<String, dynamic>;

      return MediaFile(
        id: data['id'] ?? 0,
        url: data['source_url'] ?? '',
        title: data['title']?['rendered'] ?? fileName,
        altText: data['alt_text'] ?? '',
        caption: data['caption']?['rendered'],
        mimeType: data['mime_type'] ?? contentType,
        width: data['media_details']?['width'],
        height: data['media_details']?['height'],
        fileSize: data['media_details']?['filesize'],
        dataCreazione: data['date'] != null
            ? DateTime.tryParse(data['date'])
            : null,
      );
    } catch (e) {
      throw Exception('Media upload failed: $e');
    }
  }

  /// Upload da URL
  Future<MediaFile> uploadFromUrl(
    String imageUrl, {
    String? title,
    String? altText,
  }) async {
    try {
      final data = <String, dynamic>{
        'url': imageUrl,
        if (title != null) 'title': title,
        if (altText != null) 'alt_text': altText,
      };

      final response = await _woo.dio.post(
        '${_wooConnect.siteUrl}/wp-json/wp/v2/media',
        data: data,
      );

      final responseData = response.data as Map<String, dynamic>;

      return MediaFile(
        id: responseData['id'] ?? 0,
        url: responseData['source_url'] ?? imageUrl,
        title: responseData['title']?['rendered'] ?? '',
        altText: responseData['alt_text'] ?? '',
        caption: responseData['caption']?['rendered'],
        mimeType: responseData['mime_type'] ?? '',
        width: responseData['media_details']?['width'],
        height: responseData['media_details']?['height'],
        dataCreazione: responseData['date'] != null
            ? DateTime.tryParse(responseData['date'])
            : null,
      );
    } catch (e) {
      throw Exception('Upload from URL failed: $e');
    }
  }

  /// Ottiene info media per ID
  Future<MediaFile> getMediaById(int id) async {
    try {
      final response = await _woo.dio.get(
        '${_wooConnect.siteUrl}/wp-json/wp/v2/media/$id',
      );

      final data = response.data as Map<String, dynamic>;

      return MediaFile(
        id: data['id'] ?? 0,
        url: data['source_url'] ?? '',
        title: data['title']?['rendered'] ?? '',
        altText: data['alt_text'] ?? '',
        caption: data['caption']?['rendered'],
        mimeType: data['mime_type'] ?? '',
        width: data['media_details']?['width'],
        height: data['media_details']?['height'],
        fileSize: data['media_details']?['filesize'],
        dataCreazione: data['date'] != null
            ? DateTime.tryParse(data['date'])
            : null,
      );
    } catch (e) {
      throw Exception('Media $id load failed: $e');
    }
  }

  /// Ottiene lista media
  Future<List<MediaFile>> getMediaList({
    int page = 1,
    int perPage = 20,
    String? search,
    String? mimeType,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (search != null) 'search': search,
        if (mimeType != null) 'mime_type': mimeType,
        // Aggiungi context=view per accesso pubblico quando possibile
        'context': 'view',
      };

      final response = await _woo.dio.get(
        '${_wooConnect.siteUrl}/wp-json/wp/v2/media',
        queryParameters: queryParams,
      );

      final dataList = response.data as List<dynamic>;

      return dataList.map((data) {
        return MediaFile(
          id: data['id'] ?? 0,
          url: data['source_url'] ?? '',
          title: data['title']?['rendered'] ?? '',
          altText: data['alt_text'] ?? '',
          caption: data['caption']?['rendered'],
          mimeType: data['mime_type'] ?? '',
          width: data['media_details']?['width'],
          height: data['media_details']?['height'],
          fileSize: data['media_details']?['filesize'],
          dataCreazione: data['date'] != null
              ? DateTime.tryParse(data['date'])
              : null,
        );
      }).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        log.e(
          'Errore 403: accesso negato ai media. Risposta: ${e.response?.data}',
          e,
        );
        throw LocalizedException(
          'Access denied: the user may not view media (upload_files).',
          (l10n) => l10n.mediaAccessDenied,
        );
      }
      if (e.response?.statusCode == 401) {
        throw UnauthorizedException();
      }
      log.e('Errore caricamento media', e);
      throw Exception('Media list load failed: ${e.message}');
    } catch (e) {
      log.e('Errore generico caricamento media', e);
      throw Exception('Media list load failed: $e');
    }
  }

  /// Aggiorna metadata media
  Future<MediaFile> updateMedia(
    int id, {
    String? title,
    String? altText,
    String? caption,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (altText != null) data['alt_text'] = altText;
      if (caption != null) data['caption'] = caption;

      final response = await _woo.dio.put(
        '${_wooConnect.siteUrl}/wp-json/wp/v2/media/$id',
        data: data,
      );

      final responseData = response.data as Map<String, dynamic>;

      return MediaFile(
        id: responseData['id'] ?? 0,
        url: responseData['source_url'] ?? '',
        title: responseData['title']?['rendered'] ?? '',
        altText: responseData['alt_text'] ?? '',
        caption: responseData['caption']?['rendered'],
        mimeType: responseData['mime_type'] ?? '',
        width: responseData['media_details']?['width'],
        height: responseData['media_details']?['height'],
        dataCreazione: responseData['date'] != null
            ? DateTime.tryParse(responseData['date'])
            : null,
      );
    } catch (e) {
      throw Exception('Media $id update failed: $e');
    }
  }

  /// Elimina media
  Future<void> deleteMedia(int id, {bool force = false}) async {
    try {
      await _woo.dio.delete(
        '${_wooConnect.siteUrl}/wp-json/wp/v2/media/$id',
        queryParameters: {'force': force},
      );
    } catch (e) {
      throw Exception('Media $id deletion failed: $e');
    }
  }

  /// Ottiene solo immagini
  Future<List<MediaFile>> getImages({int page = 1, int perPage = 20}) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    return await getMediaList(page: page, perPage: perPage, mimeType: 'image');
  }

  /// Upload multiplo immagini
  Future<List<MediaFile>> uploadMultipleImages(List<String> filePaths) async {
    final results = <MediaFile>[];

    for (final filePath in filePaths) {
      try {
        final media = await uploadMedia(filePath);
        results.add(media);
      } catch (e) {
        // Continua con le altre anche se una fallisce
        log.e('Errore upload $filePath', e);
      }
    }

    return results;
  }

  /// Helper per determinare content type
  String _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Verifica disponibilità servizio
  Future<bool> isServiceAvailable() async {
    try {
      await _woo.dio.get(
        '${_wooConnect.siteUrl}/wp-json/wp/v2/media',
        queryParameters: {'per_page': 1},
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
