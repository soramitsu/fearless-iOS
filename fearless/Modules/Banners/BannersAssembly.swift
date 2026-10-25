import UIKit
import SoraFoundation
import RobinHood

final class BannersAssembly {
    static func configureModule(
        output: BannersModuleOutput?,
        type: BannersModuleType,
        wallet: MetaAccountModel?
    ) -> BannersModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let walletProvider = AccountProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        ).createManagedMetaAccountProvider(
            for: NSPredicate.selectedMetaAccount(),
            sortDescriptors: []
        )

        let interactor = BannersInteractor(
            walletProvider: walletProvider,
            eventCenter: EventCenter.shared
        )

        let router = BannersRouter()

        let presenter = BannersPresenter(
            logger: Logger.shared,
            moduleOutput: output,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            type: type,
            wallet: wallet
        )

        let view = BannersViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
