import Foundation
import CommonWallet

enum FearlessTransferValidatingError: Error {
    case receiverBalanceTooLow
    case senderBalanceTooLow
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
        case .senderBalanceTooLow:
            title = R.string.localizable
                .walletSendDeadRecipientTitle(preferredLanguages: locale?.rLanguages)
            message = "You have to pay a fee over and above the existential deposit." // TODO:
        }

        return ErrorContent(title: title, message: message)
    }
}
