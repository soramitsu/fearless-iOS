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
        let settings = SettingsManager.shared
        let chain = settings.selectedConnection.type.chain
        let interactor = ControllerAccountInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            settings: settings
        )
        let wireframe = ControllerAccountWireframe()
        guard let selectedAccountAddress = settings.selectedAccount?.address else {
            return nil
        }
        let viewModelFactory = ControllerAccountViewModelFactory(
            selectedAccountAddress: selectedAccountAddress,
            iconGenerator: PolkadotIconGenerator()
        )

        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            applicationConfig: ApplicationConfig.shared,
            chain: chain
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
