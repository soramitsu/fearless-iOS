import UIKit
import SoraFoundation

final class BackupWalletNameAssembly {
    static func configureModule(with wallet: MetaAccountModel?) -> BackupWalletNameModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = BackupWalletNameInteractor(
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared,
            repository: AccountRepositoryFactory.createRepository()
        )
        let router = BackupWalletNameRouter()

        let mode = WalletNameScreenMode(wallet: wallet)
        let presenter = BackupWalletNamePresenter(
            mode: mode,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BackupWalletNameViewController(
            mode: mode,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
