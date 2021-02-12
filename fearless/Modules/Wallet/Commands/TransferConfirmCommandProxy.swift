import Foundation
import CommonWallet
import SoraFoundation
import RobinHood
import CoreData

final class TransferConfirmCommandProxy<T: Identifiable, U: NSManagedObject>: WalletCommandDecoratorProtocol {
    var calleeCommand: WalletCommandDecoratorProtocol & WalletCommandDecoratorDelegateProtocol
    private var storage: CoreDataRepository<T, U>

    var undelyingCommand: WalletCommandProtocol? {
        get { calleeCommand.undelyingCommand }
        set { calleeCommand.undelyingCommand = newValue }
        }

    let logger = Logger.shared

    init(payload: ConfirmationPayload,
         localizationManager: LocalizationManagerProtocol,
         commandFactory: WalletCommandFactoryProtocol,
         storage: CoreDataRepository<T, U>) {
        self.storage = storage
        self.calleeCommand = TransferConfirmCommand(payload: payload,
                                                  localizationManager: localizationManager,
                                                  commandFactory: commandFactory)
    }

    func execute() throws {
        let destinationKey = calleeCommand.payload.transferInfo.destination

        let fetchOperation = storage.fetchOperation(by: destinationKey,
                                                    options: RepositoryFetchOptions())
        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                self.handleAccountFetch(result: fetchOperation.result)
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [fetchOperation], in: .sync)
    }

    private func handleAccountFetch(result: Result<T?, Error>?) {
        switch result {
        case .success(let account):
            guard account != nil else {
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
