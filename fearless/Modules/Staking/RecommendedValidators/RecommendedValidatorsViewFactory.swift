import Foundation

final class RecommendedValidatorsViewFactory: RecommendedValidatorsViewFactoryProtocol {
    static func createView() -> RecommendedValidatorsViewProtocol? {
        let view = RecommendedValidatorsViewController(nib: R.nib.recommendedValidatorsViewController)
        let presenter = RecommendedValidatorsPresenter()
        let interactor = RecommendedValidatorsInteractor()
        let wireframe = RecommendedValidatorsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
