/// error_list.dart
///
/// Gestione centralizzata delle eccezioni per l'applicazione WooCommerce
/// Contiene tutte le eccezioni personalizzate per:
/// - Errori di connessione e trasporto
/// - Errori specifici di WooCommerce (prodotti, ordini, etc.)
/// - Errori di business logic per ogni servizio
/// - Gestione e parsing degli errori HTTP

import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'dart:convert';

import '../../l10n/extensions.dart';
import '../../l10n/known_messages.dart';
import '../../l10n/localized_text.dart';

/// Classe base per tutte le eccezioni personalizzate dell'applicazione.
abstract class AppException implements Exception {
  /// Testo inglese per i log; la GUI usa [localizedMessage].
  final String message;
  final int? statusCode;

  /// Testo tradotto; `null` quando il messaggio arriva dal server.
  final LocalizedText? localized;

  AppException(this.message, {this.statusCode, this.localized});

  /// Messaggio da mostrare all'operatore nella lingua attiva.
  String localizedMessage(AppLocalizations l10n) =>
      localized?.call(l10n) ?? knownMessageText(l10n, message);

  @override
  String toString() => message;
}

// =========================================================================
// ==                 ECCEZIONI DI TRASPORTO E CONNESSIONE                ==
// =========================================================================

class ConnectionException extends AppException {
  ConnectionException(String details)
    : super(
        'Network error: $details',
        localized: (l10n) => l10n.apiErrorConnection(details),
      );

  /// Rete non raggiungibile.
  ConnectionException.network()
    : super(
        'Network error: network unreachable',
        localized: (l10n) => l10n.apiErrorNetwork,
      );

  /// Per le sottoclassi con un messaggio proprio.
  ConnectionException.withMessage(String message, LocalizedText localized)
    : super(message, localized: localized);

  /// Richiesta annullata prima della risposta.
  ConnectionException.cancelled()
    : super(
        'Network error: request cancelled',
        localized: (l10n) => l10n.apiErrorRequestCancelled,
      );
}

class ConnectionTimeoutException extends ConnectionException {
  ConnectionTimeoutException()
    : super.withMessage(
        'Network error: the server did not answer in time.',
        (l10n) => l10n.apiErrorTimeout,
      );
}

/// Errore con un testo inglese per i log e uno tradotto per la GUI.
class LocalizedException extends AppException {
  LocalizedException(String message, LocalizedText localized)
    : super(message, localized: localized);
}

class InvalidCredentialsException extends AppException {
  InvalidCredentialsException(String message, {LocalizedText? localized})
    : super(message, statusCode: 403, localized: localized);
}

class UnauthorizedException extends AppException {
  UnauthorizedException()
    : super(
        'Invalid or expired session. Please log in again.',
        localized: (l10n) => l10n.apiErrorUnauthorized,
        statusCode: 401,
      );
}

class ForbiddenException extends AppException {
  ForbiddenException()
    : super(
        'You do not have permission to perform this operation.',
        localized: (l10n) => l10n.apiErrorForbidden,
        statusCode: 403,
      );
}

class NotFoundException extends AppException {
  NotFoundException(String resource)
    : super(
        'The resource "$resource" was not found on the server.',
        localized: (l10n) => l10n.apiErrorResourceNotFound(resource),
        statusCode: 404,
      );
}

class ServerException extends AppException {
  ServerException()
    : super(
        'An internal server error occurred. Try again later.',
        localized: (l10n) => l10n.apiErrorServer,
        statusCode: 500,
      );
}

class InvalidResponseFormatException extends AppException {
  InvalidResponseFormatException()
    : super(
        'The server response is not in a readable format (JSON).',
        localized: (l10n) => l10n.apiErrorInvalidResponse,
      );
}

/// Classe concreta per errori generici non gestiti
class UnhandledApiException extends AppException {
  UnhandledApiException({required int statusCode})
    : super(
        'Unhandled API error.',
        localized: (l10n) => l10n.apiErrorUnhandled,
        statusCode: statusCode,
      );
}

// =========================================================================
// ==                 ECCEZIONI DI BUSINESS LOGIC (WOOCOMMERCE)           ==
// =========================================================================

abstract class WooCommerceException extends AppException {
  final String code;
  WooCommerceException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'WooCommerce error: $message (code: $code)';
}

// === ERRORI PRODOTTI ===
class ProductNotFoundException extends WooCommerceException {
  ProductNotFoundException()
    : super(
        code: 'product_invalid_id',
        message: 'The requested product does not exist.',
        localized: (l10n) => l10n.apiErrorProductNotFound,
        statusCode: 404,
      );
}

class BarcodeInternoAlreadyExistsException extends WooCommerceException {
  BarcodeInternoAlreadyExistsException()
    : super(
        code: 'product_sku_already_exists',
        message: 'An internal barcode must be unique.',
        localized: (l10n) => l10n.apiErrorBarcodeExists,
        statusCode: 400,
      );
}

class GenericWooCommerceException extends WooCommerceException {
  GenericWooCommerceException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// === ERRORI CATEGORIE ===
abstract class CategoryException extends AppException {
  final String code;
  CategoryException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Category error: $message (code: $code)';
}

class CategoryNotFoundException extends CategoryException {
  CategoryNotFoundException()
    : super(
        code: 'category_invalid_id',
        message: 'The requested category does not exist.',
        localized: (l10n) => l10n.apiErrorCategoryNotFound,
        statusCode: 404,
      );
}

class GenericCategoryException extends CategoryException {
  GenericCategoryException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// === ERRORI TAG ===
abstract class TagException extends AppException {
  final String code;
  TagException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Tag error: $message (code: $code)';
}

class TagNotFoundException extends TagException {
  TagNotFoundException()
    : super(
        code: 'tag_invalid_id',
        message: 'The requested tag does not exist.',
        localized: (l10n) => l10n.apiErrorTagNotFound,
        statusCode: 404,
      );
}

class TagNameAlreadyExistsException extends TagException {
  TagNameAlreadyExistsException()
    : super(
        code: 'tag_name_exists',
        message: 'A tag with this name already exists.',
        localized: (l10n) => l10n.apiErrorTagNameExists,
        statusCode: 400,
      );
}

class TagSlugAlreadyExistsException extends TagException {
  TagSlugAlreadyExistsException()
    : super(
        code: 'tag_slug_exists',
        message: 'A tag with this slug already exists.',
        localized: (l10n) => l10n.apiErrorTagSlugExists,
        statusCode: 400,
      );
}

class GenericTagException extends TagException {
  GenericTagException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// === ERRORI ATTRIBUTI ===
abstract class AttributeException extends AppException {
  final String code;
  AttributeException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Attribute error: $message (code: $code)';
}

class AttributeNotFoundException extends AttributeException {
  AttributeNotFoundException()
    : super(
        code: 'attribute_invalid_id',
        message: 'The requested attribute does not exist.',
        localized: (l10n) => l10n.apiErrorAttributeNotFound,
        statusCode: 404,
      );
}

class AttributeSlugAlreadyExistsException extends AttributeException {
  AttributeSlugAlreadyExistsException()
    : super(
        code: 'attribute_slug_exists',
        message: 'An attribute with this slug already exists.',
        localized: (l10n) => l10n.apiErrorAttributeSlugExists,
        statusCode: 400,
      );
}

class AttributeTermNotFoundException extends AttributeException {
  AttributeTermNotFoundException()
    : super(
        code: 'attribute_term_invalid_id',
        message: 'The requested attribute term does not exist.',
        localized: (l10n) => l10n.apiErrorAttributeTermNotFound,
        statusCode: 404,
      );
}

class GenericAttributeException extends AttributeException {
  GenericAttributeException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// === ERRORI VARIANTI ===
abstract class VariationException extends AppException {
  final String code;
  VariationException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Variant error: $message (code: $code)';
}

class VariationNotFoundException extends VariationException {
  VariationNotFoundException()
    : super(
        code: 'variation_invalid_id',
        message: 'The requested variant does not exist.',
        localized: (l10n) => l10n.apiErrorVariationNotFound,
        statusCode: 404,
      );
}

class VariationAttributesRequiredException extends VariationException {
  VariationAttributesRequiredException()
    : super(
        code: 'variation_attributes_required',
        message: 'Attributes are required for variants.',
        localized: (l10n) => l10n.apiErrorVariationAttributesRequired,
        statusCode: 400,
      );
}

class VariationBarcodeInternoAlreadyExistsException extends VariationException {
  VariationBarcodeInternoAlreadyExistsException()
    : super(
        code: 'variation_sku_exists',
        message: 'A variant with this internal barcode already exists.',
        localized: (l10n) => l10n.apiErrorVariationBarcodeExists,
        statusCode: 400,
      );
}

class GenericVariationException extends VariationException {
  GenericVariationException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// === ERRORI MEDIA ===
abstract class MediaException extends AppException {
  final String code;
  MediaException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Media error: $message (code: $code)';
}

class MediaNotFoundException extends MediaException {
  MediaNotFoundException()
    : super(
        code: 'media_invalid_id',
        message: 'The requested media does not exist.',
        localized: (l10n) => l10n.apiErrorMediaNotFound,
        statusCode: 404,
      );
}

class MediaUploadException extends MediaException {
  MediaUploadException(String details)
    : super(
        code: 'media_upload_failed',
        message: 'Upload error: $details',
        localized: (l10n) => l10n.apiErrorUpload(details),
        statusCode: 400,
      );
}

class InvalidMediaTypeException extends MediaException {
  InvalidMediaTypeException(String mimeType)
    : super(
        code: 'invalid_media_type',
        message: 'Unsupported file type: $mimeType',
        localized: (l10n) => l10n.apiErrorUnsupportedFileType(mimeType),
        statusCode: 400,
      );
}

class MediaFileTooLargeException extends MediaException {
  MediaFileTooLargeException()
    : super(
        code: 'media_file_too_large',
        message: 'The file is too large to upload.',
        localized: (l10n) => l10n.apiErrorMediaTooLarge,
        statusCode: 413,
      );
}

class GenericMediaException extends MediaException {
  GenericMediaException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// === ERRORI ORDINI ===
abstract class OrderException extends AppException {
  final String code;
  OrderException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Order error: $message (code: $code)';
}

class OrderNotFoundException extends OrderException {
  OrderNotFoundException()
    : super(
        code: 'order_invalid_id',
        message: 'The requested order does not exist.',
        localized: (l10n) => l10n.apiErrorOrderNotFound,
        statusCode: 404,
      );
}

class InvalidOrderStatusException extends OrderException {
  InvalidOrderStatusException()
    : super(
        code: 'invalid_order_status',
        message: 'The specified order status is not valid.',
        localized: (l10n) => l10n.apiErrorInvalidOrderStatus,
        statusCode: 400,
      );
}

class OrderAlreadyPaidException extends OrderException {
  OrderAlreadyPaidException()
    : super(
        code: 'order_already_paid',
        message: 'The order has already been paid.',
        localized: (l10n) => l10n.apiErrorOrderAlreadyPaid,
        statusCode: 400,
      );
}

class OrderCannotBeModifiedException extends OrderException {
  OrderCannotBeModifiedException()
    : super(
        code: 'order_cannot_be_modified',
        message: 'The order cannot be changed in its current status.',
        localized: (l10n) => l10n.apiErrorOrderCannotBeModified,
        statusCode: 400,
      );
}

class GenericOrderException extends OrderException {
  GenericOrderException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// =========================================================================
// ==                     ECCEZIONI SPECIFICHE REPORT                     ==
// =========================================================================

abstract class ReportException extends AppException {
  final String code;
  ReportException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Report error: $message (code: $code)';
}

class GenericReportException extends ReportException {
  GenericReportException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// =========================================================================
// ==                     ECCEZIONI SPECIFICHE COUPON                     ==
// =========================================================================

abstract class CouponException extends AppException {
  final String code;
  CouponException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Coupon error: $message (code: $code)';
}

class CouponNotFoundException extends CouponException {
  CouponNotFoundException()
    : super(
        code: 'coupon_invalid_code',
        message: 'The requested coupon does not exist.',
        localized: (l10n) => l10n.apiErrorCouponNotFound,
        statusCode: 404,
      );
}

class CouponCodeAlreadyExistsException extends CouponException {
  CouponCodeAlreadyExistsException()
    : super(
        code: 'coupon_code_exists',
        message: 'The coupon code already exists.',
        localized: (l10n) => l10n.apiErrorCouponCodeExists,
        statusCode: 400,
      );
}

class CouponExpiredException extends CouponException {
  CouponExpiredException()
    : super(
        code: 'coupon_expired',
        message: 'The coupon has expired.',
        localized: (l10n) => l10n.apiErrorCouponExpired,
        statusCode: 400,
      );
}

class CouponUsageLimitException extends CouponException {
  CouponUsageLimitException()
    : super(
        code: 'coupon_usage_limit',
        message: 'The coupon has reached its usage limit.',
        localized: (l10n) => l10n.apiErrorCouponUsageLimit,
        statusCode: 400,
      );
}

class GenericCouponException extends CouponException {
  GenericCouponException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// =========================================================================
// ==                     ECCEZIONI SPECIFICHE TASSE                      ==
// =========================================================================

abstract class TaxException extends AppException {
  final String code;
  TaxException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Tax error: $message (code: $code)';
}

class TaxClassNotFoundException extends TaxException {
  TaxClassNotFoundException()
    : super(
        code: 'tax_class_invalid',
        message: 'The requested tax class does not exist.',
        localized: (l10n) => l10n.apiErrorTaxClassNotFound,
        statusCode: 404,
      );
}

class TaxRateNotFoundException extends TaxException {
  TaxRateNotFoundException()
    : super(
        code: 'tax_rate_invalid',
        message: 'The requested tax rate does not exist.',
        localized: (l10n) => l10n.apiErrorTaxRateNotFound,
        statusCode: 404,
      );
}

class InvalidTaxLocationException extends TaxException {
  InvalidTaxLocationException()
    : super(
        code: 'invalid_tax_location',
        message: 'The specified tax location is not valid.',
        localized: (l10n) => l10n.apiErrorInvalidTaxLocation,
        statusCode: 400,
      );
}

class GenericTaxException extends TaxException {
  GenericTaxException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// =========================================================================
// ==                     ECCEZIONI SPECIFICHE CLIENTI                    ==
// =========================================================================

abstract class CustomerException extends AppException {
  final String code;
  CustomerException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Customer error: $message (code: $code)';
}

class CustomerNotFoundException extends CustomerException {
  CustomerNotFoundException()
    : super(
        code: 'customer_invalid_id',
        message: 'The requested customer does not exist.',
        localized: (l10n) => l10n.apiErrorCustomerNotFound,
        statusCode: 404,
      );
}

class InvalidCustomerEmailException extends CustomerException {
  InvalidCustomerEmailException()
    : super(
        code: 'invalid_email',
        message: 'The email address is not valid.',
        localized: (l10n) => l10n.apiErrorInvalidEmail,
        statusCode: 400,
      );
}

class CustomerEmailAlreadyExistsException extends CustomerException {
  CustomerEmailAlreadyExistsException()
    : super(
        code: 'email_exists',
        message: 'The email address is already in use.',
        localized: (l10n) => l10n.apiErrorEmailExists,
        statusCode: 400,
      );
}

class InvalidCustomerUsernameException extends CustomerException {
  InvalidCustomerUsernameException()
    : super(
        code: 'invalid_username',
        message: 'The username is not valid.',
        localized: (l10n) => l10n.apiErrorInvalidUsername,
        statusCode: 400,
      );
}

class CustomerUsernameAlreadyExistsException extends CustomerException {
  CustomerUsernameAlreadyExistsException()
    : super(
        code: 'username_exists',
        message: 'The username is already in use.',
        localized: (l10n) => l10n.apiErrorUsernameExists,
        statusCode: 400,
      );
}

class GenericCustomerException extends CustomerException {
  GenericCustomerException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// =========================================================================
// ==                     ECCEZIONI SPECIFICHE SPEDIZIONI                 ==
// =========================================================================

abstract class ShippingException extends AppException {
  final String code;
  ShippingException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Shipping error: $message (code: $code)';
}

class ShippingZoneNotFoundException extends ShippingException {
  ShippingZoneNotFoundException()
    : super(
        code: 'shipping_zone_invalid',
        message: 'The requested shipping zone does not exist.',
        localized: (l10n) => l10n.apiErrorShippingZoneNotFound,
        statusCode: 404,
      );
}

class ShippingMethodNotFoundException extends ShippingException {
  ShippingMethodNotFoundException()
    : super(
        code: 'shipping_method_invalid',
        message: 'The requested shipping method does not exist.',
        localized: (l10n) => l10n.apiErrorShippingMethodNotFound,
        statusCode: 404,
      );
}

class ShippingClassNotFoundException extends ShippingException {
  ShippingClassNotFoundException()
    : super(
        code: 'shipping_class_invalid',
        message: 'The requested shipping class does not exist.',
        localized: (l10n) => l10n.apiErrorShippingClassNotFound,
        statusCode: 404,
      );
}

class InvalidShippingLocationException extends ShippingException {
  InvalidShippingLocationException()
    : super(
        code: 'invalid_shipping_location',
        message: 'The specified shipping location is not valid.',
        localized: (l10n) => l10n.apiErrorInvalidShippingLocation,
        statusCode: 400,
      );
}

class GenericShippingException extends ShippingException {
  GenericShippingException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// =========================================================================
// ==                     ECCEZIONI SPECIFICHE BATCH                      ==
// =========================================================================

abstract class BatchException extends AppException {
  final String code;
  BatchException({
    required this.code,
    required String message,
    int? statusCode,
    super.localized,
  }) : super(message, statusCode: statusCode);
  @override
  String toString() => 'Batch operation error: $message (code: $code)';
}

class InvalidBatchDataException extends BatchException {
  InvalidBatchDataException([String? details])
    : super(
        code: 'invalid_batch_data',
        message: details != null
            ? 'Invalid batch operation data: $details'
            : 'Invalid batch operation data.',
        localized: (l10n) => details != null
            ? l10n.apiErrorInvalidBatchDataDetail(details)
            : l10n.apiErrorInvalidBatchData,
        statusCode: 400,
      );
}

class BatchLimitExceededException extends BatchException {
  BatchLimitExceededException()
    : super(
        code: 'batch_limit_exceeded',
        message: 'The maximum limit for batch operations was exceeded.',
        localized: (l10n) => l10n.apiErrorBatchLimit,
        statusCode: 400,
      );
}

class BatchOperationFailedException extends BatchException {
  BatchOperationFailedException([String? details])
    : super(
        code: 'batch_operation_failed',
        message: details != null
            ? 'Batch operation failed: $details'
            : 'Batch operation failed.',
        localized: (l10n) => details != null
            ? l10n.apiErrorBatchFailedDetail(details)
            : l10n.apiErrorBatchFailed,
        statusCode: 500,
      );
}

class GenericBatchException extends BatchException {
  GenericBatchException({
    required super.code,
    required super.message,
    super.statusCode,
  });
}

// =========================================================================
// ==                       GESTORE DEGLI ERRORI                          ==
// =========================================================================

class ErrorHandler {
  static void throwFromResponse(http.Response response) {
    final int statusCode = response.statusCode;

    // Errori di trasporto/autenticazione
    switch (statusCode) {
      case 401:
        throw UnauthorizedException();
      case 403:
        throw ForbiddenException();
      case 404:
        throw NotFoundException(response.request?.url.path ?? 'resource');
      case 500:
      case 502:
      case 503:
      case 504:
        throw ServerException();
    }

    // Errori di business logic di WooCommerce
    if (statusCode == 400) {
      try {
        final jsonBody = jsonDecode(response.body);
        final String code = jsonBody['code'] ?? '';
        final String message = jsonBody['message'] ?? 'Invalid data sent.';

        // Mappa errori specifici alle eccezioni tipizzate
        switch (code) {
          // === ERRORI PRODOTTI ===
          case 'woocommerce_rest_product_invalid_id':
            throw ProductNotFoundException();
          case 'woocommerce_rest_product_sku_already_exists':
            throw BarcodeInternoAlreadyExistsException();

          // === ERRORI CATEGORIE ===
          case 'woocommerce_rest_product_category_invalid_id':
            throw CategoryNotFoundException();

          // === ERRORI TAG ===
          case 'woocommerce_rest_product_tag_invalid_id':
            throw TagNotFoundException();

          // === ERRORI ATTRIBUTI ===
          case 'woocommerce_rest_product_attribute_invalid_id':
            throw AttributeNotFoundException();
          case 'woocommerce_rest_product_attribute_term_invalid_id':
            throw AttributeTermNotFoundException();

          // === ERRORI VARIANTI ===
          case 'woocommerce_rest_product_variation_invalid_id':
            throw VariationNotFoundException();

          // === ERRORI MEDIA ===
          case 'woocommerce_rest_attachment_invalid_id':
            throw MediaNotFoundException();

          // === ERRORI ORDINI ===
          case 'woocommerce_rest_shop_order_invalid_id':
            throw OrderNotFoundException();
          case 'woocommerce_rest_invalid_order_status':
            throw InvalidOrderStatusException();

          // === ERRORI CLIENTI ===
          case 'woocommerce_rest_customer_invalid_id':
            throw CustomerNotFoundException();
          case 'woocommerce_rest_customer_invalid_email':
            throw InvalidCustomerEmailException();
          case 'registration-error-email-exists':
            throw CustomerEmailAlreadyExistsException();
          case 'registration-error-username-exists':
            throw CustomerUsernameAlreadyExistsException();
          case 'woocommerce_rest_invalid_username':
            throw InvalidCustomerUsernameException();

          // === ERRORI COUPON ===
          case 'woocommerce_rest_shop_coupon_invalid_id':
            throw CouponNotFoundException();
          case 'woocommerce_rest_coupon_code_already_exists':
            throw CouponCodeAlreadyExistsException();
          case 'woocommerce_rest_coupon_expired':
            throw CouponExpiredException();
          case 'woocommerce_rest_coupon_usage_limit_reached':
            throw CouponUsageLimitException();

          // === ERRORI TASSE ===
          case 'woocommerce_rest_tax_class_invalid':
            throw TaxClassNotFoundException();
          case 'woocommerce_rest_tax_rate_invalid_id':
            throw TaxRateNotFoundException();
          case 'woocommerce_rest_invalid_tax_location':
            throw InvalidTaxLocationException();

          // === ERRORI SPEDIZIONI ===
          case 'woocommerce_rest_shipping_zone_invalid_id':
            throw ShippingZoneNotFoundException();
          case 'woocommerce_rest_shipping_zone_method_invalid_id':
            throw ShippingMethodNotFoundException();
          case 'woocommerce_rest_shipping_class_invalid_id':
            throw ShippingClassNotFoundException();
          case 'woocommerce_rest_invalid_shipping_location':
            throw InvalidShippingLocationException();

          // === ERRORI BATCH ===
          case 'woocommerce_rest_invalid_batch_data':
            throw InvalidBatchDataException();
          case 'woocommerce_rest_batch_limit_exceeded':
            throw BatchLimitExceededException();
          case 'woocommerce_rest_batch_operation_failed':
            throw BatchOperationFailedException();

          // === ERRORI GENERICI ===
          default:
            // Determina il tipo di eccezione generica in base al contesto
            if (code.startsWith('woocommerce_rest_product')) {
              throw GenericWooCommerceException(
                code: code,
                message: message,
                statusCode: statusCode,
              );
            } else if (code.contains('coupon')) {
              throw GenericCouponException(
                code: code,
                message: message,
                statusCode: statusCode,
              );
            } else if (code.contains('customer')) {
              throw GenericCustomerException(
                code: code,
                message: message,
                statusCode: statusCode,
              );
            } else if (code.contains('tax')) {
              throw GenericTaxException(
                code: code,
                message: message,
                statusCode: statusCode,
              );
            } else if (code.contains('shipping')) {
              throw GenericShippingException(
                code: code,
                message: message,
                statusCode: statusCode,
              );
            } else if (code.contains('batch')) {
              throw GenericBatchException(
                code: code,
                message: message,
                statusCode: statusCode,
              );
            } else {
              // Fallback per errori completamente sconosciuti
              throw GenericWooCommerceException(
                code: code,
                message: message,
                statusCode: statusCode,
              );
            }
        }
      } on FormatException {
        throw InvalidResponseFormatException();
      }
    }

    // Fallback per errori non previsti
    throw UnhandledApiException(statusCode: statusCode);
  }

  /// Gestisce gli errori da DioException
  static Never throwFromDioException(DioException e) {
    if (e.response != null) {
      final response = e.response!;
      final statusCode = response.statusCode ?? 0;

      // Errori di trasporto/autenticazione
      switch (statusCode) {
        case 401:
          throw UnauthorizedException();
        case 403:
          throw ForbiddenException();
        case 404:
          throw NotFoundException(e.requestOptions.path);
        case 500:
        case 502:
        case 503:
        case 504:
          throw ServerException();
      }

      // Errori di business logic di WooCommerce
      if (statusCode == 400 && response.data != null) {
        try {
          final jsonBody = response.data is Map
              ? response.data
              : jsonDecode(response.data.toString());
          final String code = jsonBody['code'] ?? '';
          final String message = jsonBody['message'] ?? 'Invalid data sent.';

          // Mappa errori specifici alle eccezioni tipizzate
          switch (code) {
            // === ERRORI PRODOTTI ===
            case 'woocommerce_rest_product_invalid_id':
              throw ProductNotFoundException();
            case 'woocommerce_rest_product_sku_already_exists':
              throw BarcodeInternoAlreadyExistsException();

            // === ERRORI CATEGORIE ===
            case 'woocommerce_rest_product_category_invalid_id':
              throw CategoryNotFoundException();

            // === ERRORI TAG ===
            case 'woocommerce_rest_product_tag_invalid_id':
              throw TagNotFoundException();

            // === ERRORI ATTRIBUTI ===
            case 'woocommerce_rest_product_attribute_invalid_id':
              throw AttributeNotFoundException();
            case 'woocommerce_rest_product_attribute_term_invalid_id':
              throw AttributeTermNotFoundException();

            // === ERRORI VARIANTI ===
            case 'woocommerce_rest_product_variation_invalid_id':
              throw VariationNotFoundException();

            // === ERRORI MEDIA ===
            case 'woocommerce_rest_attachment_invalid_id':
              throw MediaNotFoundException();

            // === ERRORI ORDINI ===
            case 'woocommerce_rest_shop_order_invalid_id':
              throw OrderNotFoundException();
            case 'woocommerce_rest_invalid_order_status':
              throw InvalidOrderStatusException();

            // === ERRORI CLIENTI ===
            case 'woocommerce_rest_customer_invalid_id':
              throw CustomerNotFoundException();
            case 'woocommerce_rest_customer_invalid_email':
              throw InvalidCustomerEmailException();
            case 'registration-error-email-exists':
              throw CustomerEmailAlreadyExistsException();
            case 'registration-error-username-exists':
              throw CustomerUsernameAlreadyExistsException();
            case 'woocommerce_rest_invalid_username':
              throw InvalidCustomerUsernameException();

            // === ERRORI COUPON ===
            case 'woocommerce_rest_shop_coupon_invalid_id':
              throw CouponNotFoundException();
            case 'woocommerce_rest_coupon_code_already_exists':
              throw CouponCodeAlreadyExistsException();
            case 'woocommerce_rest_coupon_expired':
              throw CouponExpiredException();
            case 'woocommerce_rest_coupon_usage_limit_reached':
              throw CouponUsageLimitException();

            // === ERRORI TASSE ===
            case 'woocommerce_rest_tax_class_invalid':
              throw TaxClassNotFoundException();
            case 'woocommerce_rest_tax_rate_invalid_id':
              throw TaxRateNotFoundException();
            case 'woocommerce_rest_invalid_tax_location':
              throw InvalidTaxLocationException();

            // === ERRORI SPEDIZIONI ===
            case 'woocommerce_rest_shipping_zone_invalid_id':
              throw ShippingZoneNotFoundException();
            case 'woocommerce_rest_shipping_zone_method_invalid_id':
              throw ShippingMethodNotFoundException();
            case 'woocommerce_rest_shipping_class_invalid_id':
              throw ShippingClassNotFoundException();
            case 'woocommerce_rest_invalid_shipping_location':
              throw InvalidShippingLocationException();

            // === ERRORI BATCH ===
            case 'woocommerce_rest_invalid_batch_data':
              throw InvalidBatchDataException();
            case 'woocommerce_rest_batch_limit_exceeded':
              throw BatchLimitExceededException();
            case 'woocommerce_rest_batch_operation_failed':
              throw BatchOperationFailedException();

            // === ERRORI GENERICI ===
            default:
              // Determina il tipo di eccezione generica in base al contesto
              if (code.startsWith('woocommerce_rest_product')) {
                throw GenericWooCommerceException(
                  code: code,
                  message: message,
                  statusCode: statusCode,
                );
              } else if (code.contains('coupon')) {
                throw GenericCouponException(
                  code: code,
                  message: message,
                  statusCode: statusCode,
                );
              } else if (code.contains('customer')) {
                throw GenericCustomerException(
                  code: code,
                  message: message,
                  statusCode: statusCode,
                );
              } else if (code.contains('tax')) {
                throw GenericTaxException(
                  code: code,
                  message: message,
                  statusCode: statusCode,
                );
              } else if (code.contains('shipping')) {
                throw GenericShippingException(
                  code: code,
                  message: message,
                  statusCode: statusCode,
                );
              } else if (code.contains('batch')) {
                throw GenericBatchException(
                  code: code,
                  message: message,
                  statusCode: statusCode,
                );
              } else {
                // Fallback per errori completamente sconosciuti
                throw GenericWooCommerceException(
                  code: code,
                  message: message,
                  statusCode: statusCode,
                );
              }
          }
        } on FormatException {
          throw InvalidResponseFormatException();
        }
      }

      // Fallback per errori non previsti
      throw UnhandledApiException(statusCode: statusCode);
    } else {
      // Errori di connessione senza risposta
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw ConnectionTimeoutException();
        case DioExceptionType.connectionError:
          throw ConnectionException.network();
        case DioExceptionType.cancel:
          throw ConnectionException.cancelled();
        default:
          throw ConnectionException(e.message ?? 'unknown error');
      }
    }
  }
}
