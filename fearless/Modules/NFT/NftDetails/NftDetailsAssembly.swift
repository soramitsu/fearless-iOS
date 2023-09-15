import UIKit
import SoraFoundation

final class NftDetailsAssembly {
    static func configureModule(nft: NFT, wallet: MetaAccountModel, address: String) -> NftDetailsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = NftDetailsInteractor(nft: nft)
        let router = NftDetailsRouter()

        let presenter = NftDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            address: address,
            viewModelFactory: NftDetailViewModelFactory(),
            nft: nft,
            wallet: wallet
        )

        let view = NftDetailsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
