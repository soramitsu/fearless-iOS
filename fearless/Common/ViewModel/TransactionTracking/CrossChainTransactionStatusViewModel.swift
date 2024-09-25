import Foundation
import UIKit

enum CrossChainStepStatus {
    case pending
    case failed
    case refund
    case success
}

struct CrossChainTransactionStatusViewModel {
    let status: CrossChainStepStatus

    var color: UIColor? {
        switch status {
        case .pending:
            return R.color.colorWhite16()
        case .failed:
            return R.color.colorRed()
        case .refund:
            return R.color.colorOrange()
        case .success:
            return R.color.colorGreen()
        }
    }

    func title(for locale: Locale) -> String? {
        switch status {
        case .pending:
            return nil
        case .failed:
            return R.string.localizable.transactionStatusFailed(preferredLanguages: locale.rLanguages)
        case .refund:
            return "Refund"
        case .success:
            return R.string.localizable.allDoneAlertSuccessStub(preferredLanguages: locale.rLanguages)
        }
    }
}
