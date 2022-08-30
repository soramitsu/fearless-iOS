import UIKit
import SoraFoundation

final class NetworkIssuesNotificationAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        issues: [ChainIssue]
    ) -> NetworkIssuesNotificationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = NetworkIssuesNotificationInteractor()
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
