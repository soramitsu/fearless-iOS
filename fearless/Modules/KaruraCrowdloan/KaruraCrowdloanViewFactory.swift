import Foundation

struct KaruraCrowdloanViewFactory {
    static func createView() -> KaruraCrowdloanViewProtocol? {
        let interactor = KaruraCrowdloanInteractor()
        let wireframe = KaruraCrowdloanWireframe()

        let presenter = KaruraCrowdloanPresenter(interactor: interactor, wireframe: wireframe)

        let view = KaruraCrowdloanViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
