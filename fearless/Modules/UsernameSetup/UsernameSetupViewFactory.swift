import Foundation
import SoraFoundation

final class UsernameSetupViewFactory: UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol? {
        let wireframe = UsernameSetupWireframe()
        return createView(for: wireframe)
    }

    static func createViewForAdding() -> UsernameSetupViewProtocol? {
        let wireframe = AddAccount.UsernameSetupWireframe()
        return createView(for: wireframe)
    }

    static func createViewForConnection(item: ConnectionItem) -> UsernameSetupViewProtocol? {
        let wireframe = SelectConnection.UsernameSetupWireframe(connectionItem: item)
        return createView(for: wireframe)
    }

    static func createViewForSwitch() -> UsernameSetupViewProtocol? {
        let wireframe = SwitchAccount.UsernameSetupWireframe()
        return createView(for: wireframe)
    }

    private static func createView(for wireframe: UsernameSetupWireframeProtocol)
    -> UsernameSetupViewProtocol? {
        let view = UsernameSetupViewController(nib: R.nib.usernameSetupViewController)
        let presenter = UsernameSetupPresenter()

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        view.localizationManager = LocalizationManager.shared
        presenter.localizationManager = LocalizationManager.shared

        return view
    }
}
