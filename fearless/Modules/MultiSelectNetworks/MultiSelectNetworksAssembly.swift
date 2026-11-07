import UIKit
import SoraFoundation
import SSFModels

final class MultiSelectNetworksAssembly {
    static func configureModule(
        canSelect: Bool,
        dataSource: [ChainModel],
        selectedChains: [ChainModel.Id]?,
        moduleOutput: MultiSelectNetworksModuleOutput?
    ) -> MultiSelectNetworksModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = MultiSelectNetworksInteractor()
        let router = MultiSelectNetworksRouter()

        let presenter = MultiSelectNetworksPresenter(
            canSelect: canSelect,
            dataSource: dataSource,
            selectedChains: selectedChains,
            viewModelFactory: MultiSelectNetworksViewModelFactoryImpl(),
            moduleOutput: moduleOutput,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = MultiSelectNetworksViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
