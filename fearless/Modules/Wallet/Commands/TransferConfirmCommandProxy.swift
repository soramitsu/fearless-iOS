import Foundation
import CommonWallet
import SoraFoundation
import RobinHood
import CoreData

final class TransferConfirmCommandProxy: WalletCommandDecoratorProtocol {
    private var commandFactory: WalletCommandFactoryProtocol
    private var storage: AnyDataProviderRepository<PhishingItem>
    private var locale: Locale

    var calleeCommand: WalletCommandDecoratorProtocol & WalletCommandDecoratorDelegateProtocol

    var undelyingCommand: WalletCommandProtocol? {
        get { calleeCommand.undelyingCommand }
        set { calleeCommand.undelyingCommand = newValue }
    }

    let logger = Logger.shared

    init(payload: ConfirmationPayload,
         localizationManager: LocalizationManagerProtocol,
         commandFactory: WalletCommandFactoryProtocol,
         storage: AnyDataProviderRepository<PhishingItem>) {
        self.locale = localizationManager.selectedLocale
        self.storage = storage
        self.commandFactory = commandFactory
        self.calleeCommand = TransferConfirmCommand(payload: payload,
                                                    localizationManager: localizationManager,
                                                    commandFactory: commandFactory)
    }

    func execute() throws {
        let nextAction = {
            try? self.calleeCommand.execute()
            return
        }

        let cancelAction = {
            let hideCommand = self.commandFactory.prepareHideCommand(with: .pop)
            try? hideCommand.execute()
        }

        let phishingCheckExecutor: PhishingCheckExecutorProtocol =
            PhishingCheckExecutor(commandFactory: commandFactory,
                                  storage: storage,
                                  nextAction: nextAction,
                                  cancelAction: cancelAction,
                                  locale: locale)

        phishingCheckExecutor.checkPhishing(
            publicKey: calleeCommand.payload.transferInfo.destination,
            walletAddress: calleeCommand.payload.receiverName)
    }
}
