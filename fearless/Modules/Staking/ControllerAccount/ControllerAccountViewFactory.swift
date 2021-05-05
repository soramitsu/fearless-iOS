import Foundation
import SoraFoundation

struct ControllerAccountViewFactory {
    static func createView() -> ControllerAccountViewProtocol? {
        let interactor = ControllerAccountInteractor()
        let wireframe = ControllerAccountWireframe()

        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            applicationConfig: ApplicationConfig.shared
        )

        let view = ControllerAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
