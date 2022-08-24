import UIKit
import SoraFoundation
import SoraUI

final class WalletOptionAssembly {
    static func configureModule(with wallet: ManagedMetaAccountModel) -> WalletOptionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = WalletOptionInteractor(wallet: wallet)
        let router = WalletOptionRouter()

        let presenter = WalletOptionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletOptionViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
