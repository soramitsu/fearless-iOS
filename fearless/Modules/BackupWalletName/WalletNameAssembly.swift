import UIKit
import SoraFoundation

final class WalletNameAssembly {
    static func configureModule(with wallet: MetaAccountModel?) -> WalletNameModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = WalletNameInteractor(
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared,
            repository: AccountRepositoryFactory.createRepository()
        )
        let router = WalletNameRouter()

        let mode = WalletNameScreenMode(wallet: wallet)
        let presenter = WalletNamePresenter(
            mode: mode,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletNameViewController(
            mode: mode,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
