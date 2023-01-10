import UIKit
import SoraFoundation

final class SoraCardInfoBoardAssembly {
    static func configureModule() -> SoraCardInfoBoardModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let service: SCKYCService = .init(client: .shared)

        let interactor = SoraCardInfoBoardInteractor(data: SCKYCUserDataModel(), service: service)
        let router = SoraCardInfoBoardRouter()

        let presenter = SoraCardInfoBoardPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            viewModelFactory: SoraCardStateViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = SoraCardInfoBoardViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
