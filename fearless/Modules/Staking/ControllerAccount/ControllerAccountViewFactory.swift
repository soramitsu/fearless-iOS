import Foundation
import SoraFoundation

struct ControllerAccountViewFactory {
    static func createView() -> ControllerAccountViewProtocol? {
        let presenter = ControllerAccountPresenter()
        let interactor = ControllerAccountInteractor()
        let wireframe = ControllerAccountWireframe()

        let view = ControllerAccountViewController(
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
