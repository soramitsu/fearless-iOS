import UIKit
import SoraFoundation
import RobinHood

final class NetworkIssuesNotificationAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        issues: [ChainIssue]
    ) -> NetworkIssuesNotificationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createRepository()

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: []
        )

        let missingAccountHelper = MissingAccountFetcher(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainsIssuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper
        )

        let interactor = NetworkIssuesNotificationInteractor(
            wallet: wallet,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            chainsIssuesCenter: chainsIssuesCenter
        )

        let router = NetworkIssuesNotificationRouter()

        let presenter = NetworkIssuesNotificationPresenter(
            wallet: wallet,
            issues: issues,
            viewModelFactory: NetworkIssuesNotificationViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = NetworkIssuesNotificationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
