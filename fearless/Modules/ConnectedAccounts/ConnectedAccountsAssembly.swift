import UIKit
import SoraFoundation
import SSFNetwork
import SoraKeystore

final class ConnectedAccountsAssembly {
    static func configureModule() -> ConnectedAccountsModuleCreationResult? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }
        let localizationManager = LocalizationManager.shared

        let interactor = ConnectedAccountsInteractor(
            wallet: wallet,
            chainRepository: ServiceAssembly.shared.asyncChainModelRepository(),
            walletBalanceSubscriptionAdapter: ServiceAssembly.shared.walletBalanceSubscriptionAdapter,
            eventCenter: ServiceAssembly.shared.eventCenter
        )
        let router = ConnectedAccountsRouter()

        let accountScoreFetcher = NomisAccountStatisticsFetcher(
            networkWorker: NetworkWorkerImpl(),
            signer: NomisRequestSigner()
        )
        let viewModelFactory = ConnectedAccountsViewModelFactoryImpl(
            accountScoreFetcher: accountScoreFetcher,
            settings: SettingsManager.shared
        )

        let presenter = ConnectedAccountsPresenter(
            wallet: wallet,
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = ConnectedAccountsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
