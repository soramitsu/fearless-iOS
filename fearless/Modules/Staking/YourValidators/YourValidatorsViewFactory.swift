import Foundation
import SoraFoundation

final class YourValidatorsViewFactory: YourValidatorsViewFactoryProtocol {
    static func createView() -> YourValidatorsViewProtocol? {
        let interactor = YourValidatorsInteractor()
        let wireframe = YourValidatorsWireframe()
        let presenter = YourValidatorsPresenter(interactor: interactor, wireframe: wireframe)

        let view = YourValidatorsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
