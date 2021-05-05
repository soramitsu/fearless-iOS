import Foundation

struct ControllerAccountViewFactory {
    static func createView() -> ControllerAccountViewProtocol? {
        let view = ControllerAccountViewController()
        let presenter = ControllerAccountPresenter()
        let interactor = ControllerAccountInteractor()
        let wireframe = ControllerAccountWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
