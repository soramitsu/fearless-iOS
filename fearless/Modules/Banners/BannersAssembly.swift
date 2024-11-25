import UIKit
import SoraFoundation
import RobinHood
import SSFModels

final class BannersAssembly {
    static func configureModule(
        output: BannersModuleOutput?,
        type: BannersModuleType,
        wallet: MetaAccountModel?
    ) -> BannersModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let walletProvider = UserDataStorageFacade.shared
            .createStreamableProvider(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
            )
        
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let interactor = BannersInteractor(
            walletProvider: walletProvider,
            chainAssetFetching: chainAssetFetching,
            eventCenter: EventCenter.shared,
            userDefaults: ServiceAssembly.shared.userDefaults
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
