import Foundation
import SoraFoundation
import FearlessUtils

struct ControllerAccountConfirmationViewFactory {
    static func createView(
        stashAccountItem: AccountItem,
        controllerAccountItem: AccountItem
    ) -> ControllerAccountConfirmationViewProtocol? {
        let interactor = ControllerAccountConfirmationInteractor()
        let wireframe = ControllerAccountConfirmationWireframe()
        let presenter = ControllerAccountConfirmationPresenter(
            stashAccountItem: stashAccountItem,
            controllerAccountItem: controllerAccountItem,
            iconGenerator: PolkadotIconGenerator()
        )

        let view = ControllerAccountConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
