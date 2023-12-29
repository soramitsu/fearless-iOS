import UIKit
import SoraFoundation
import SSFModels
import RobinHood

final class NftCollectionAssembly {
    static func configureModule(collection: NFTCollection, wallet: MetaAccountModel, address: String) -> NftCollectionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let nftFetchingService = AlchemyNftFetchingService(
            operationFactory: AlchemyNFTOperationFactory(),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let interactor = NftCollectionInteractor(collection: collection, nftFetchingService: nftFetchingService)
        let router = NftCollectionRouter()
        let viewModelFactory = NftCollectionViewModelFactory()
        let presenter = NftCollectionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            address: address,
            wallet: wallet
        )

        let view = NftCollectionViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
