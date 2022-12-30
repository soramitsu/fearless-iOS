import UIKit
import SoraFoundation

final class AssetListSearchAssembly {
    static func configureModule(wallet: MetaAccountModel) -> AssetListSearchModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = AssetListSearchInteractor()
        let router = AssetListSearchRouter()

        guard let assetListModule = Self.configureAssetListModule(wallet: wallet) else {
            return nil
        }

        let presenter = AssetListSearchPresenter(
            assetListModuleInput: assetListModule.input,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = AssetListSearchViewController(
            assetListViewController: assetListModule.view.controller,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    private static func configureAssetListModule(
        wallet: MetaAccountModel
    ) -> ChainAssetListModuleCreationResult? {
        ChainAssetListAssembly.configureModule(
            wallet: wallet
        )
    }
}
