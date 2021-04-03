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
    let dataStorageFacade: StorageFacadeProtocol

    init(
        localizationManager: LocalizationManagerProtocol,
        dataStorageFacade: StorageFacadeProtocol
    ) {
        self.localizationManager = localizationManager
        self.dataStorageFacade = dataStorageFacade
    }

    func createTransferConfirmationDecorator(
        with commandFactory: WalletCommandFactoryProtocol,
        payload: ConfirmationPayload
    ) -> WalletCommandDecoratorProtocol? {
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            dataStorageFacade.createRepository()

        return TransferConfirmCommandProxy(
            payload: payload,
            localizationManager: localizationManager,
            commandFactory: commandFactory,
            storage: AnyDataProviderRepository(storage)
        )
    }
}
