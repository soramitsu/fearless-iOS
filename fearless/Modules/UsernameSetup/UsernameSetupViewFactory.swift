import Foundation
import SoraFoundation
import SoraKeystore

final class UsernameSetupViewFactory: UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding(flow: AccountCreateFlow = .wallet) -> UsernameSetupViewProtocol? {
        let wireframe = UsernameSetupWireframe()
        return createView(for: wireframe, flow: flow)
    }

    static func createViewForAdding() -> UsernameSetupViewProtocol? {
        let wireframe = AddAccount.UsernameSetupWireframe()
        return createView(for: wireframe)
    }

    static func createViewForSwitch() -> UsernameSetupViewProtocol? {
        let wireframe = SwitchAccount.UsernameSetupWireframe()

        return createView(for: wireframe)
    }

    private static func createView(
        for wireframe: UsernameSetupWireframeProtocol,
        flow: AccountCreateFlow = .wallet
    ) -> UsernameSetupViewProtocol? {
        let presenter = UsernameSetupPresenter(
            wireframe: wireframe,
            flow: flow,
            localizationManager: LocalizationManager.shared
        )
        let view = UsernameSetupViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        return view
    }
}
