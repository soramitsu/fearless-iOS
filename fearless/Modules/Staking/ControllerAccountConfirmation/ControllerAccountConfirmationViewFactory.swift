import Foundation
import SoraFoundation

struct ControllerAccountConfirmationViewFactory {
    static func createView() -> ControllerAccountConfirmationViewProtocol? {
        let interactor = ControllerAccountConfirmationInteractor()
        let wireframe = ControllerAccountConfirmationWireframe()
        let presenter = ControllerAccountConfirmationPresenter()

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
