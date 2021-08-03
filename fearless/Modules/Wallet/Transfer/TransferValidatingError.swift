import Foundation
import CommonWallet

enum FearlessTransferValidatingError: Error {
    case receiverBalanceTooLow
    case cantPayFee
}

extension FearlessTransferValidatingError: WalletErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> WalletErrorContentProtocol {
        let title: String
        let message: String

        switch self {
        case .receiverBalanceTooLow:
            title = R.string.localizable
                .walletSendDeadRecipientTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .walletSendDeadRecipientMessage(preferredLanguages: locale?.rLanguages)
        case .cantPayFee:
            title = R.string.localizable
                .walletSendDeadRecipientTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .walletFeeOverExistentialDeposit(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
