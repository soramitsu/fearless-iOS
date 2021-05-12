import Foundation

struct ControllerAccountConfirmationViewFactory {
    static func createView() -> ControllerAccountConfirmationViewProtocol? {
        let view = ControllerAccountConfirmationViewController()
        let presenter = ControllerAccountConfirmationPresenter()
        let interactor = ControllerAccountConfirmationInteractor()
        let wireframe = ControllerAccountConfirmationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
