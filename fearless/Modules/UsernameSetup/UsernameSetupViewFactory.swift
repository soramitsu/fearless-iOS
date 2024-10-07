import Foundation
import SoraFoundation
import SoraKeystore

final class UsernameSetupViewFactory: UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding(
        flow: AccountCreateFlow = .wallet,
        ecosystem: AccountCreateEcosystem
    ) -> UsernameSetupViewProtocol? {
        let wireframe = UsernameSetupWireframe()
        return createView(for: wireframe, flow: flow, ecosystem: ecosystem)
    }

    static func createViewForAdding(
        ecosystem: AccountCreateEcosystem
    ) -> UsernameSetupViewProtocol? {
        let wireframe = AddAccount.UsernameSetupWireframe()
        return createView(for: wireframe, ecosystem: ecosystem)
    }

    static func createViewForSwitch(
        ecosystem: AccountCreateEcosystem
    ) -> UsernameSetupViewProtocol? {
        let wireframe = SwitchAccount.UsernameSetupWireframe()

        return createView(for: wireframe, ecosystem: ecosystem)
    }

    private static func createView(
        for wireframe: UsernameSetupWireframeProtocol,
        flow: AccountCreateFlow = .wallet,
        ecosystem: AccountCreateEcosystem
    ) -> UsernameSetupViewProtocol? {
        let presenter = UsernameSetupPresenter(
            wireframe: wireframe,
            flow: flow, 
            ecosystem: ecosystem,
            localizationManager: LocalizationManager.shared
        )
        let view = UsernameSetupViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        return view
    }
}
