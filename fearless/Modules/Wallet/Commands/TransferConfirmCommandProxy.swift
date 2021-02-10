import Foundation
import CommonWallet
import SoraFoundation
import RobinHood

final class TransferConfirmCommandProxy: WalletCommandDecoratorProtocol {
    var calleeCommand: WalletCommandDecoratorProtocol & WalletCommandDecoratorDelegateProtocol

    var undelyingCommand: WalletCommandProtocol? {
        get { calleeCommand.undelyingCommand }
        set { calleeCommand.undelyingCommand = newValue }
        }

    let logger = Logger.shared

    init(payload: ConfirmationPayload,
         localizationManager: LocalizationManagerProtocol,
         commandFactory: WalletCommandFactoryProtocol) {
        self.calleeCommand = TransferConfirmCommand(payload: payload,
                                                  localizationManager: localizationManager,
                                                  commandFactory: commandFactory)
    }

    func execute() throws {
        let destinationKey = calleeCommand.payload.transferInfo.destination

        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let fetchOperation = storage.fetchOperation(by: destinationKey,
                                                    options: RepositoryFetchOptions())
        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                self.handleAccountFetch(result: fetchOperation.result)
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [fetchOperation], in: .sync)
    }

    private func handleAccountFetch(result: Result<PhishingItem?, Error>?) {
        switch result {
        case .success(let account):
            guard account == nil else {
                try? self.calleeCommand.execute()
                return
            }

            self.issueWarning()

        case .failure(let error):
            self.logger.error(error.localizedDescription)

        case .none:
            self.logger.error("Scam account fetch operation cancelled")
        }
    }

    private func issueWarning() {
        let locale = self.calleeCommand.localizationManager.selectedLocale

        let title = R.string.localizable.walletSendPhishingWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.walletSendPhishingWarningText(calleeCommand.payload.receiverName,
                                                                         preferredLanguages: locale.rLanguages)

        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)

        let continueTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in
            try? self.calleeCommand.execute()
        }

        alertController.addAction(continueAction)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancelAction = UIAlertAction(title: cancelTitle,
                                        style: .cancel,
                                        handler: cancelActionHandler(alert:))
        alertController.addAction(cancelAction)

        let presentationCommand = calleeCommand.commandFactory?.preparePresentationCommand(for: alertController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try? presentationCommand?.execute()
    }

    func cancelActionHandler(alert: UIAlertAction!) {
        let hideCommand = calleeCommand.commandFactory?.prepareHideCommand(with: .pop)

        try? hideCommand?.execute()
    }
}
