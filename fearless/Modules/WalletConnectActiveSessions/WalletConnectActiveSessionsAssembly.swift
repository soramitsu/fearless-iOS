import UIKit
import SoraFoundation

final class WalletConnectActiveSessionsAssembly {
    static func configureModule() -> WalletConnectActiveSessionsModuleCreationResult? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }
        let localizationManager = LocalizationManager.shared

        let interactor = WalletConnectActiveSessionsInteractor(
            wallet: wallet,
            walletConnectService: WalletConnectServiceImpl.shared,
            appRepository: ServiceAssembly.shared.tonConnectAppAsyncRepository(),
            tonConnectService: ServiceAssembly.shared.tonConnectService(),
            eventCenter: ServiceAssembly.shared.eventCenter
        )
        let router = WalletConnectActiveSessionsRouter()

        let presenter = WalletConnectActiveSessionsPresenter(
            wallet: wallet,
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
