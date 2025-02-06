import UIKit

enum OKXCrossChainTxDetailStatus: String {
    case waiting = "WAITING" // (Order processing)
    case fromSuccess = "FROM_SUCCESS" // (Source swap success)
    case fromFailure = "FROM_FAILURE" // (Source swap failure)
    case bridgePending = "BRIDGE_PENDING" // (Bridge pending)
    case bridgeSuccess = "BRIDGE_SUCCESS" // (Bridge success)
    case success = "SUCCESS" // (Order success)
    case refund = "REFUND" // (Order failure, refund)
    case notFound = "NOT_FOUND"

    init(txDetailStatus: String?) {
        switch txDetailStatus?.lowercased() {
        case "pending":
            self = .waiting
        case "success":
            self = .success
        case "fail":
            self = .fromFailure
        default:
            self = .notFound
        }
    }
    
    func statusDescription(locale: Locale) -> String {
        switch self {
        case .waiting:
            return R.string.localizable.crossChainTxDetailStatusWaitingDescription(preferredLanguages: locale.rLanguages)
        case .fromSuccess:
            return R.string.localizable.crossChainTxDetailStatusFromSuccessDescription(preferredLanguages: locale.rLanguages)
        case .fromFailure:
            return R.string.localizable.crossChainTxDetailStatusFromFailureDescription(preferredLanguages: locale.rLanguages)
        case .bridgePending:
            return R.string.localizable.crossChainTxDetailStatusBridgePendingDescription(preferredLanguages: locale.rLanguages)
        case .bridgeSuccess:
            return R.string.localizable.crossChainTxDetailStatusBrideSuccessDescription(preferredLanguages: locale.rLanguages)
        case .success:
            return R.string.localizable.crossChainTxDetailStatusSuccessDescription(preferredLanguages: locale.rLanguages)
        case .refund:
            return R.string.localizable.crossChainTxDetailStatusRefundDescription(preferredLanguages: locale.rLanguages)
        case .notFound:
            return R.string.localizable.commonNotFound(preferredLanguages: locale.rLanguages)
        }
    }
    
    func statusColor() -> UIColor? {
        switch self {
        case .waiting:
            R.color.warning_yellow()
        case .fromSuccess:
            R.color.warning_yellow()
        case .fromFailure:
            R.color.error_red()
        case .bridgePending:
            R.color.warning_yellow()
        case .bridgeSuccess:
            R.color.success_green()
        case .success:
            R.color.success_green()
        case .refund:
            R.color.warning_orange()
        case .notFound:
            R.color.colorStrokeGray()
        }
    }
}
