import UIKit
import SoraFoundation

final class PolkaswapSwapConfirmationAssembly {
    static func configureModule(
        params: PolkaswapPreviewParams,
        completeClosure: (() -> Void)?
    ) -> PolkaswapSwapConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        // Runtime, connection, account, signer, builder and executor are all
        // resolved by the authorizer at submit time; assembly state is preview
        // state only and is never granted submission authority.
        let interactor = PolkaswapSwapConfirmationInteractor(params: params)
        let router = PolkaswapSwapConfirmationRouter()

        let presenter = PolkaswapSwapConfirmationPresenter(
            params: params,
            viewModelFactory: PolkaswapSwapConfirmationViewModelFactory(),
            interactor: interactor,
            router: router,
            completeClosure: completeClosure,
            localizationManager: localizationManager
        )

        let view = PolkaswapSwapConfirmationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
