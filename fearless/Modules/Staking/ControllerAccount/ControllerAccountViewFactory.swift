import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils

struct ControllerAccountViewFactory {
    static func createView() -> ControllerAccountViewProtocol? {
        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let interactor = ControllerAccountInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            settings: SettingsManager.shared
        )
        let wireframe = ControllerAccountWireframe()
        let viewModelFactory = ControllerAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            applicationConfig: ApplicationConfig.shared
        )

        let view = ControllerAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
