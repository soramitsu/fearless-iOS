import Foundation

struct AnalyticsViewFactory {
    static func createView() -> AnalyticsViewProtocol? {
        let interactor = AnalyticsInteractor()
        let wireframe = AnalyticsWireframe()

        let presenter = AnalyticsPresenter(interactor: interactor, wireframe: wireframe)

        let view = AnalyticsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
