import UIKit
import SoraFoundation
import RobinHood

final class NftDetailsAssembly {
    static func configureModule(
        nft: NFT,
        wallet: MetaAccountModel,
        address: String,
        type: NftType
    ) -> NftDetailsModuleCreationResult? {
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

        let interactor = NftDetailsInteractor(nft: nft, nftFetchingService: nftFetchingService)
        let router = NftDetailsRouter()

        let presenter = NftDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            address: address,
            viewModelFactory: NftDetailViewModelFactory(),
            nft: nft,
            wallet: wallet,
            type: type
        )

        let view = NftDetailsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
