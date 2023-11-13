import UIKit
import SoraFoundation
import SSFModels

final class NftCollectionAssembly {
    static func configureModule(collection: NFTCollection, wallet: MetaAccountModel, address: String) -> NftCollectionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = NftCollectionInteractor(collection: collection)
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
