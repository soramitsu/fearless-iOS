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
            guard account == nil else { // TODO: Change to "!=" for production version
                try? self.calleeCommand.execute()
                return
            }

            self.showWarning()

        case .failure(let error):
            self.logger.error(error.localizedDescription)

        case .none:
            self.logger.error("Scam account fetch operation cancelled")
        }
    }

    private func showWarning() {
        let locale = self.calleeCommand.localizationManager.selectedLocale

        let alertController = UIAlertController.phishingWarningAlert(onConfirm: { () -> Void in
            try? self.calleeCommand.execute()
        }, onCancel: { () -> Void in
            let hideCommand = self.calleeCommand.commandFactory?.prepareHideCommand(with: .pop)
            try? hideCommand?.execute()
        }, locale: locale,
        publicKey: calleeCommand.payload.receiverName)

        let presentationCommand = calleeCommand.commandFactory?.preparePresentationCommand(for: alertController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try? presentationCommand?.execute()
    }
}
