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

        let walletProvider = UserDataStorageFacade.shared
            .createStreamableProvider(
                filter: NSPredicate.selectedMetaAccount(),
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
            )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = BannersInteractor(
            walletProvider: walletProvider,
            repository: accountRepository,
            operationQueue: OperationQueue()
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
