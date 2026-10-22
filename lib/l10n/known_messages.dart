import 'generated/app_localizations.dart';

/// Testi fissi che il codice senza contesto mette al posto del messaggio del
/// server (ad esempio 'MGWS backend not available'). Sono in inglese, la
/// lingua di riferimento; [knownMessageText] li traduce quando vengono
/// mostrati. Un messaggio sconosciuto, come quello del server, resta com'e.
abstract final class AppMessages {
  static const mgwsPluginTooOld =
      'The MGWS plugin on the site is too old: update it to version 2.4.0 or later to use sites.';
  static const mgwsUnavailable = 'MGWS backend not available';
  static const mgwsUnreachable = 'MGWS service not reachable';
  static const mgwsServerUnreachable = 'MGWS server not reachable.';
  static const noSiteConnected = 'No site connected';
  static const receiptListMalformed = 'Unstructured receipt list';
  static const documentUpdateMalformed = 'Unstructured document update';
  static const closingListMalformed = 'Unstructured closing list';
  static const closingMalformed = 'Unstructured closing';
  static const closingAdjustmentMalformed = 'Unstructured closing adjustment';
  static const receiptDetailMalformed = 'Unstructured receipt detail';
  static const invalidServerResponse = 'Invalid server response.';
  static const stockSyncDone = 'Stock sync completed';
  static const stockSyncFailed = 'Stock sync failed';
  static const reconcileDone = 'Reconciliation completed';
  static const reconcileFailed = 'Reconciliation failed';
  static const moveDone = 'Transfer completed';
  static const moveFailed = 'Transfer failed';
  static const rfidResolved = 'RFID resolved without updating stock';
  static const rfidNotResolved = 'RFID not resolved';
  static const mgwsOperationDone = 'MGWS operation completed';
  static const mgwsInvalidResponse = 'Invalid MGWS response';
  static const mgwsListLoaded = 'MGWS list loaded';
  static const employeePermissionsReadFailed =
      'Could not read the employee permissions';
  static const nothingToSave = 'No changes to save';
  static const employeePermissionsUpdateFailed =
      'Could not update the employee permissions';
  static const employeeAppPasswordsLoadFailed =
      'Could not load the employee Application Passwords';
  static const appPasswordRevokeFailed =
      'Could not revoke the Application Password';
  static const employeeWooKeysLoadFailed =
      'Could not load the employee WooCommerce keys';
  static const wooKeyRevokeFailed = 'Could not revoke the WooCommerce key';
  static const couponInvalid = 'Invalid coupon';
  static const couponNotFound = 'Coupon not found';
  static const noBatchOperation = 'No batch operation specified';
  static const variantNeedsAttribute =
      'The variant must have at least one attribute';
}

String knownMessageText(
  AppLocalizations l10n,
  String message,
) => switch (message) {
  AppMessages.mgwsPluginTooOld => l10n.msgMgwsPluginTooOld,
  AppMessages.mgwsUnavailable => l10n.msgMgwsUnavailable,
  AppMessages.mgwsUnreachable => l10n.msgMgwsUnreachable,
  AppMessages.mgwsServerUnreachable => l10n.msgMgwsServerUnreachable,
  AppMessages.noSiteConnected => l10n.msgNoSiteConnected,
  AppMessages.receiptListMalformed => l10n.msgReceiptListMalformed,
  AppMessages.documentUpdateMalformed => l10n.msgDocumentUpdateMalformed,
  AppMessages.closingListMalformed => l10n.msgClosingListMalformed,
  AppMessages.closingMalformed => l10n.msgClosingMalformed,
  AppMessages.closingAdjustmentMalformed => l10n.msgClosingAdjustmentMalformed,
  AppMessages.receiptDetailMalformed => l10n.msgReceiptDetailMalformed,
  AppMessages.invalidServerResponse => l10n.msgInvalidServerResponse,
  AppMessages.stockSyncDone => l10n.msgStockSyncDone,
  AppMessages.stockSyncFailed => l10n.msgStockSyncFailed,
  AppMessages.reconcileDone => l10n.msgReconcileDone,
  AppMessages.reconcileFailed => l10n.msgReconcileFailed,
  AppMessages.moveDone => l10n.msgMoveDone,
  AppMessages.moveFailed => l10n.msgMoveFailed,
  AppMessages.rfidResolved => l10n.msgRfidResolved,
  AppMessages.rfidNotResolved => l10n.msgRfidNotResolved,
  AppMessages.mgwsOperationDone => l10n.msgMgwsOperationDone,
  AppMessages.mgwsInvalidResponse => l10n.msgMgwsInvalidResponse,
  AppMessages.mgwsListLoaded => l10n.msgMgwsListLoaded,
  AppMessages.employeePermissionsReadFailed =>
    l10n.msgEmployeePermissionsReadFailed,
  AppMessages.nothingToSave => l10n.msgNothingToSave,
  AppMessages.employeePermissionsUpdateFailed =>
    l10n.msgEmployeePermissionsUpdateFailed,
  AppMessages.employeeAppPasswordsLoadFailed =>
    l10n.msgEmployeeAppPasswordsLoadFailed,
  AppMessages.appPasswordRevokeFailed => l10n.msgAppPasswordRevokeFailed,
  AppMessages.employeeWooKeysLoadFailed => l10n.msgEmployeeWooKeysLoadFailed,
  AppMessages.wooKeyRevokeFailed => l10n.msgWooKeyRevokeFailed,
  AppMessages.couponInvalid => l10n.msgCouponInvalid,
  AppMessages.couponNotFound => l10n.msgCouponNotFound,
  AppMessages.noBatchOperation => l10n.msgNoBatchOperation,
  AppMessages.variantNeedsAttribute => l10n.msgVariantNeedsAttribute,
  _ => message,
};
