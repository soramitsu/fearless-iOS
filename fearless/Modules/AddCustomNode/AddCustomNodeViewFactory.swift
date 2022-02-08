import Foundation

struct AddCustomNodeViewFactory {
    static func createView() -> AddCustomNodeViewProtocol? {
        let interactor = AddCustomNodeInteractor()
        let wireframe = AddCustomNodeWireframe()

        let presenter = AddCustomNodePresenter(interactor: interactor, wireframe: wireframe)

        let view = AddCustomNodeViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
