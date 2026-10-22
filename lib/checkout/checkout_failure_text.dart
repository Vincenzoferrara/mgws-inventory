import '../l10n/extensions.dart';
import 'checkout_failure.dart';

/// Testo tradotto di un [CassaFailure], da leggere in `build` o subito prima
/// di mostrare il messaggio.
extension CassaFailureText on CassaFailure {
  String testo(AppLocalizations l10n) {
    switch (code) {
      case CassaFailureCode.shiftAlreadyOpen:
        return l10n.cassaErrorShiftAlreadyOpen;
      case CassaFailureCode.shiftNotFound:
        return l10n.cassaErrorShiftNotFound;
      case CassaFailureCode.shiftAlreadyClosed:
        return l10n.cassaErrorShiftAlreadyClosed;
      case CassaFailureCode.noOpenShift:
        return l10n.cassaErrorNoOpenShift;
      case CassaFailureCode.openShiftBeforeAdding:
        return l10n.cassaErrorOpenShiftBeforeAdding;
      case CassaFailureCode.closeReceiptBeforeShiftClose:
        return l10n.cassaErrorCloseReceiptBeforeShiftClose;
      case CassaFailureCode.differenceReasonRequired:
        return l10n.cassaErrorDifferenceReasonRequired;
      case CassaFailureCode.invalidServerResponse:
        return l10n.cassaErrorInvalidServerResponse;
      case CassaFailureCode.shiftOperationFailed:
        return l10n.cassaErrorShiftOperationFailed;
      case CassaFailureCode.invalidLine:
        return l10n.cassaErrorInvalidLine;
      case CassaFailureCode.insufficientStock:
        return l10n.cassaErrorInsufficientStock(
          disponibili ?? 0,
          richiesti ?? 0,
        );
      case CassaFailureCode.returnNotAllowed:
        return l10n.cassaErrorReturnNotAllowed;
      case CassaFailureCode.saleLineNotFound:
        return l10n.cassaErrorSaleLineNotFound;
      case CassaFailureCode.lineFullyReturned:
        return l10n.cassaErrorLineFullyReturned;
      case CassaFailureCode.invalidReturnQuantity:
        return l10n.cassaErrorInvalidReturnQuantity;
      case CassaFailureCode.returnReasonRequired:
        return l10n.cassaErrorReturnReasonRequired;
      case CassaFailureCode.returnExceedsRemaining:
        if (venduti != null && giaResi != null) {
          return l10n.cassaErrorReturnExceedsRemainingDetail(
            disponibili ?? 0,
            venduti!,
            giaResi!,
          );
        }
        return l10n.cassaErrorReturnExceedsRemaining(disponibili ?? 0);
      case CassaFailureCode.originReceiptNotFound:
        return l10n.cassaErrorOriginReceiptNotFound;
      case CassaFailureCode.originReceiptCancelled:
        return l10n.cassaErrorOriginReceiptCancelled;
      case CassaFailureCode.receiptNotFound:
        return l10n.cassaErrorReceiptNotFound;
      case CassaFailureCode.receiptAlreadyCancelled:
        return l10n.cassaErrorReceiptAlreadyCancelled;
      case CassaFailureCode.onlyClosedReceiptsCancellable:
        return l10n.cassaErrorOnlyClosedReceiptsCancellable;
      case CassaFailureCode.cancelReasonRequired:
        return l10n.cassaErrorCancelReasonRequired;
      case CassaFailureCode.adjustmentNoteRequired:
        return l10n.cassaErrorAdjustmentNoteRequired;
      case CassaFailureCode.couponNotFound:
        return l10n.cassaCouponNotFound;
      case CassaFailureCode.couponCheckFailed:
        return l10n.cassaCouponCheckFailed;
      case CassaFailureCode.couponUnsupportedType:
        return l10n.cassaCouponUnsupportedType;
      case CassaFailureCode.couponExpired:
        return l10n.cassaCouponExpired;
      case CassaFailureCode.couponUsageLimitReached:
        return l10n.cassaCouponUsageLimitReached;
      case CassaFailureCode.couponCustomerRequired:
        return l10n.cassaCouponCustomerRequired;
      case CassaFailureCode.couponNotForCustomer:
        return l10n.cassaCouponNotForCustomer;
      case CassaFailureCode.couponMinimumSpend:
        return l10n.cassaCouponMinimumSpend(_euro(importo));
      case CassaFailureCode.couponMaximumSpend:
        return l10n.cassaCouponMaximumSpend(_euro(importo));
      case CassaFailureCode.couponNoEligibleItems:
        return l10n.cassaCouponNoEligibleItems;
      case CassaFailureCode.server:
        return messaggio ?? l10n.cassaErrorShiftOperationFailed;
    }
  }

  static String _euro(double? valore) => '€${(valore ?? 0).toStringAsFixed(2)}';
}
