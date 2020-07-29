import Foundation
import SoraFoundation

final class UsernameSetupViewFactory: UsernameSetupViewFactoryProtocol {
    static func createView() -> UsernameSetupViewProtocol? {
        let view = UsernameSetupViewController(nib: R.nib.usernameSetupViewController)
        let presenter = UsernameSetupPresenter()
        let wireframe = UsernameSetupWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        view.localizationManager = LocalizationManager.shared
        presenter.localizationManager = LocalizationManager.shared

        return view
    }
}
