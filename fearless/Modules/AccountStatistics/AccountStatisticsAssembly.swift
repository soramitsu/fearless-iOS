import UIKit
import SoraFoundation
import SSFNetwork

final class AccountStatisticsAssembly {
    static func configureModule(address: String?) -> AccountStatisticsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountScoreFetcher = NomisAccountStatisticsFetcher(networkWorker: NetworkWorkerImpl(), signer: NomisRequestSigner())
        let interactor = AccountStatisticsInteractor(accountScoreFetcher: accountScoreFetcher, address: address)
        let router = AccountStatisticsRouter()

        let presenter = AccountStatisticsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: AccountStatisticsViewModelFactoryImpl(),
            logger: Logger.shared
        )

        let view = AccountStatisticsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
