import UIKit
import SoraFoundation
import SSFModels

final class DappBrowserListAssembly {
    static func configureModule(
        title: String,
        dapps: [TonDapp],
        wallet: MetaAccountModel
    ) -> DappBrowserListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = DappBrowserListInteractor()
        let router = DappBrowserListRouter()

        let presenter = DappBrowserListPresenter(
            wallet: wallet,
            dapps: dapps,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = DappBrowserListViewController(
            title: title,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
