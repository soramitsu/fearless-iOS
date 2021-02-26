import Foundation
import RobinHood
import CoreData
import SoraFoundation
import CommonWallet

class PhishingCheckExecutor: WalletCommandProtocol {
    private let storage: AnyDataProviderRepository<PhishingItem>
    private let nextActionBlock: () -> Void
    private let cancelActionBlock: () -> Void
    private let locale: Locale
    private let commandFactory: WalletCommandFactoryProtocol?
    private let publicKey: String
    private let displayName: String

    init(commandFactory: WalletCommandFactoryProtocol,
         storage: AnyDataProviderRepository<PhishingItem>,
         nextAction nextActionBlock: @escaping () -> Void,
         cancelAction cancelActionBlock: @escaping () -> Void,
         locale: Locale,
         publicKey: String,
         walletAddress displayName: String) {
        self.commandFactory = commandFactory
        self.storage = storage
        self.nextActionBlock = nextActionBlock
        self.cancelActionBlock = cancelActionBlock
        self.locale = locale
        self.publicKey = publicKey
        self.displayName = displayName
    }

    func execute() throws {
        let fetchOperation = storage.fetchOperation(by: publicKey,
                                                    options: RepositoryFetchOptions())

        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = try? fetchOperation.extractResultData() {

                    guard result != nil else {
                        self.nextActionBlock()
                        return
                    }

                    let alertController = UIAlertController.phishingWarningAlert(
                        onConfirm: self.nextActionBlock,
                        onCancel: self.cancelActionBlock,
                        locale: self.locale,
                        displayName: self.displayName)

                    let presentationCommand = self.commandFactory?.preparePresentationCommand(for: alertController)
                    presentationCommand?.presentationStyle = .modal(inNavigation: false)

                    try? presentationCommand?.execute()
                }

            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [fetchOperation], in: .sync)
    }
}
