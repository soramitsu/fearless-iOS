import UIKit
import SoraFoundation

final class CreateContactAssembly {
    static func configureModule(
        moduleOutput: CreateContactModuleOutput,
        chain: ChainModel,
        address: String?
    ) -> CreateContactModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = CreateContactInteractor()
        let router = CreateContactRouter()

        let viewModelFactory = CreateContactViewModelFactory()

        let presenter = CreateContactPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            moduleOutput: moduleOutput,
            chain: chain,
            address: address
        )

        let view = CreateContactViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
