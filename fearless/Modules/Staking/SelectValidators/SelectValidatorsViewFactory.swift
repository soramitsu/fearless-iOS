import Foundation

struct SelectValidatorsViewFactory {
    static func createView() -> SelectValidatorsViewProtocol? {
        let interactor = SelectValidatorsInteractor()
        let wireframe = SelectValidatorsWireframe()

        let presenter = SelectValidatorsPresenter(interactor: interactor, wireframe: wireframe)

        let view = SelectValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
