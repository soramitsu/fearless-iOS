import UIKit
import SoraFoundation

final class VerificationStatusAssembly {
    static func configureModule() -> VerificationStatusModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let service: SCKYCService = .init(client: .shared)

        let interactor = VerificationStatusInteractor(
            data: SCKYCUserDataModel(),
            service: service,
            storage: SCStorage.shared,
            eventCenter: EventCenter.shared
        )
        let router = VerificationStatusRouter()

        let logger: LoggerProtocol = Logger.shared
        let viewModelFactory: VerificationStatusViewModelFactoryProtocol = VerificationStatusViewModelFactory()

        let presenter = VerificationStatusPresenter(
            interactor: interactor,
            router: router,
            logger: logger,
            supportUrl: ApplicationConfig.shared.supportURL,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory
        )

        let view = VerificationStatusViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
