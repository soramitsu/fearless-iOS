import Foundation
import CommonWallet
import SoraFoundation
import SoraKeystore

protocol WalletSelectAccountCommandFactoryProtocol {
    func createCommand(_ walletCommandFactory: WalletCommandFactoryProtocol) -> WalletSelectAccountCommand
}

final class WalletSelectAccountCommandFactory: WalletSelectAccountCommandFactoryProtocol {
    func createCommand(_ walletCommandFactory: WalletCommandFactoryProtocol) -> WalletSelectAccountCommand {
        let storageFacade = UserDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let repositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade,
                                                         operationManager: operationManager)

        return WalletSelectAccountCommand(repositoryFactory: repositoryFactory,
                                          commandFactory: walletCommandFactory,
                                          settings: SettingsManager.shared,
                                          eventCenter: EventCenter.shared,
                                          localizationManager: LocalizationManager.shared)
    }
}
