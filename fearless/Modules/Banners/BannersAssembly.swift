import UIKit
import SoraFoundation
import RobinHood

final class BannersAssembly {
    static func configureModule(output: BannersModuleOutput?) -> BannersModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let walletProvider = UserDataStorageFacade.shared
            .createStreamableProvider(
                filter: NSPredicate.selectedMetaAccount(),
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
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
            localizationManager: localizationManager
        )

        let view = BannersViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
