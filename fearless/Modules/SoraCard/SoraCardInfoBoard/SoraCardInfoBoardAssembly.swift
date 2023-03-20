import UIKit
import SoraFoundation
import SoraKeystore

final class SoraCardInfoBoardAssembly {
    static func configureModule(wallet: MetaAccountModel) -> SoraCardInfoBoardModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let service: SCKYCService = .init(client: .shared)

        let interactor = SoraCardInfoBoardInteractor(
            service: service,
            settings: SettingsManager.shared,
            wallet: wallet
        )
        let router = SoraCardInfoBoardRouter()

        let presenter = SoraCardInfoBoardPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            viewModelFactory: SoraCardStateViewModelFactory(),
            wallet: wallet,
            localizationManager: localizationManager
        )

        let view = SoraCardInfoBoardViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
