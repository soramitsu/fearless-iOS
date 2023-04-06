import UIKit
import SoraFoundation

final class VerificationStatusAssembly {
    static func configureModule() -> VerificationStatusModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let service: SCKYCService = .init(client: .shared)

        let interactor = VerificationStatusInteractor(data: SCKYCUserDataModel(), service: service)
        let router = VerificationStatusRouter()

        let logger: LoggerProtocol = Logger.shared
        let viewModelFactory: VerificationStatusViewModelFactoryProtocol = VerificationStatusViewModelFactory()

        let presenter = VerificationStatusPresenter(
            interactor: interactor,
            router: router,
            logger: logger,
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
