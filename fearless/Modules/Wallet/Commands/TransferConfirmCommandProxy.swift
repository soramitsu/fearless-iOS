import Foundation
import CommonWallet
import SoraFoundation

final class TransferConfirmCommandProxy: WalletCommandDecoratorProtocol {
    var realCommand: WalletCommandDecoratorProtocol & WalletCommandDecoratorDelegateProtocol
    var undelyingCommand: WalletCommandProtocol? {
        get { realCommand.undelyingCommand }
        set { realCommand.undelyingCommand = newValue }
        }

    init(transferConfirmCommand: WalletCommandDecoratorProtocol & WalletCommandDecoratorDelegateProtocol) {
        self.realCommand = transferConfirmCommand
    }

    func execute() throws {
        let scamAddressProcessor = ScamAddressProcessor()
        let destinationKey = realCommand.payload.transferInfo.destination
        try? scamAddressProcessor.fetchAddress(publicKey: destinationKey,
                                               completionHandler: handleAccountFetch(result:))
    }

    func handleAccountFetch(result: Result<PhishingItem?, Error>?) {
        switch result {
        case .success(let account):
            guard account != nil else {
                try? self.realCommand.execute()
                return
            }

            issueWarning()

        case .failure(let error):
            print(error)

        case .none:
            print("none")
        }
    }

    private func issueWarning() {
        let locale = self.realCommand.localizationManager.selectedLocale

        let title = R.string.localizable.walletSendPhishingWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.walletSendPhishingWarningText(realCommand.payload.receiverName,
                                                                         preferredLanguages: locale.rLanguages)

        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)

        let continueTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in
            try? self.realCommand.execute()
        }

        alertController.addAction(continueAction)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let closeAction = UIAlertAction(title: cancelTitle,
                                        style: .cancel,
                                        handler: nil)
        alertController.addAction(closeAction)

        let presentationCommand = self.realCommand.commandFactory?.preparePresentationCommand(for: alertController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try? presentationCommand?.execute()
    }
}
