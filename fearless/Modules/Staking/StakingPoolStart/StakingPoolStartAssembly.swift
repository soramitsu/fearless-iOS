import UIKit
import SoraFoundation

final class StakingPoolStartAssembly {
    static func configureModule(chainAsset: ChainAsset) -> StakingPoolStartModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = StakingPoolStartInteractor()
        let router = StakingPoolStartRouter()
        let viewModelFactory = StakingPoolStartViewModelFactory(chainAsset: chainAsset)

        let presenter = StakingPoolStartPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory
        )

        let view = StakingPoolStartViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
