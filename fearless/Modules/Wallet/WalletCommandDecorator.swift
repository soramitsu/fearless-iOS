import Foundation
import CommonWallet
import SoraFoundation
import RobinHood

final class StubCommandDecorator: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    func execute() throws {}
}

final class WalletCommandDecoratorFactory: WalletCommandDecoratorFactoryProtocol {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func createTransferConfirmationDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                             payload: ConfirmationPayload)
        -> WalletCommandDecoratorProtocol? {

        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return TransferConfirmCommandProxy(payload: payload,
                               localizationManager: localizationManager,
                               commandFactory: commandFactory,
                               storage: AnyDataProviderRepository(storage))
    }
}
