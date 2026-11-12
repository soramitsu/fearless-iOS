import UIKit
import SoraFoundation
import SSFModels

final class AllDoneAssembly {
    static func configureModule(
        chainAsset: ChainAsset?,
        hashString: String?,
        title: String? = nil,
        description: String? = nil,
        closure: (() -> Void)? = nil,
        isWalletConnectResult: Bool = false,
        celebration: FWTransferCelebration? = nil
    ) -> AllDoneModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = AllDoneInteractor()
        let router = AllDoneRouter()
        let viewModelFactory = AllDoneViewModelFactory()

        let presenter = AllDonePresenter(
            chainAsset: chainAsset,
            hashString: hashString,
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            closure: closure,
            title: title,
            description: description,
            isWalletConnectResult: isWalletConnectResult,
            localizationManager: localizationManager
        )

        let view = AllDoneViewController(
            output: presenter,
            localizationManager: localizationManager,
            celebration: celebration
        )

        return (view, presenter)
    }
}
