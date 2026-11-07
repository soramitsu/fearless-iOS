import UIKit
import SoraFoundation

final class WalletConnectActiveSessionsAssembly {
    static func configureModule() -> WalletConnectActiveSessionsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = WalletConnectActiveSessionsInteractor(
            walletConnectService: WalletConnectServiceImpl.shared
        )
        let router = WalletConnectActiveSessionsRouter()

        let presenter = WalletConnectActiveSessionsPresenter(
            viewModelFactory: WalletConnectActiveSessionsViewModelFactoryImpl(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletConnectActiveSessionsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
