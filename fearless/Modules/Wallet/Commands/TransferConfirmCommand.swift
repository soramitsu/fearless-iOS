import Foundation
import CommonWallet
import SoraFoundation

protocol WalletCommandDecoratorDelegateProtocol {
    var payload: ConfirmationPayload { get }
    var localizationManager: LocalizationManagerProtocol { get }
    var commandFactory: WalletCommandFactoryProtocol? { get set }
}

final class TransferConfirmCommand: WalletCommandDecoratorProtocol, WalletCommandDecoratorDelegateProtocol {
    var undelyingCommand: WalletCommandProtocol?

    let payload: ConfirmationPayload

    let localizationManager: LocalizationManagerProtocol

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(payload: ConfirmationPayload,
         localizationManager: LocalizationManagerProtocol,
         commandFactory: WalletCommandFactoryProtocol) {
        self.commandFactory = commandFactory
        self.localizationManager = localizationManager
        self.payload = payload
    }

    func execute() throws {
        guard let context = payload.transferInfo.context,
            let chain = WalletAssetId(rawValue: payload.transferInfo.asset)?.chain else {
            try undelyingCommand?.execute()
            return
        }

        let balanceContext = BalanceContext(context: context)

        let transferAmount = payload.transferInfo.amount.decimalValue
        let totalFee = payload.transferInfo.fees.reduce(Decimal(0.0)) { $0 + $1.value.decimalValue }
        let totalAfterTransfer = balanceContext.total - (transferAmount + totalFee)

        guard totalAfterTransfer < chain.existentialDeposit else {
            try undelyingCommand?.execute()
            return
        }

        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.commonWarning(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.walletSendExistentialWarning(preferredLanguages: locale.rLanguages)

        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)

        let continueTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in
            try? self.undelyingCommand?.execute()
        }

        alertController.addAction(continueAction)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let closeAction = UIAlertAction(title: cancelTitle,
                                        style: .cancel,
                                        handler: nil)
        alertController.addAction(closeAction)

        let presentationCommand = commandFactory?.preparePresentationCommand(for: alertController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try? presentationCommand?.execute()
    }
}
