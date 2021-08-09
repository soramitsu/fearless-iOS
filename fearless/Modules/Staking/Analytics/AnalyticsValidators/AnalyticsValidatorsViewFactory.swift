import Foundation

struct AnalyticsValidatorsViewFactory {
    static func createView() -> AnalyticsValidatorsViewProtocol? {
        let interactor = AnalyticsValidatorsInteractor()
        let wireframe = AnalyticsValidatorsWireframe()

        let presenter = AnalyticsValidatorsPresenter(interactor: interactor, wireframe: wireframe)

        let view = AnalyticsValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
