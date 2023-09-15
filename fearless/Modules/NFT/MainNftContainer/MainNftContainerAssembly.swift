import UIKit
import SoraFoundation
import RobinHood
import SSFNetwork

final class MainNftContainerAssembly {
    static func configureModule(wallet: MetaAccountModel) -> MainNftContainerModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let nftFetchingService = AlchemyNftFetchingService(
            operationFactory: AlchemyNFTOperationFactory(),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationQueue()
        )

        let interactor = MainNftContainerInteractor(
            nftFetchingService: nftFetchingService,
            logger: Logger.shared,
            wallet: wallet,
            eventCenter: EventCenter.shared
        )
        let router = MainNftContainerRouter()

        let presenter = MainNftContainerPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: NftListViewModelFactory(),
            wallet: wallet,
            eventCenter: EventCenter.shared
        )

        let view = MainNftContainerViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
