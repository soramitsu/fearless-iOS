import Foundation
import SoraFoundation
import SoraKeystore

final class UsernameSetupViewFactory: UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol? {
        let wireframe = UsernameSetupWireframe()
        let interactor = UsernameSetupInteractor(
            supportedNetworkTypes: Chain.allCases,
            defaultNetwork: ConnectionItem.defaultConnection.type.chain
        )
        return createView(for: wireframe, interactor: interactor)
    }

    static func createViewForAdding() -> UsernameSetupViewProtocol? {
        let defaultChain = SettingsManager.shared.selectedConnection.type.chain

        let wireframe = AddAccount.UsernameSetupWireframe()
        let interactor = UsernameSetupInteractor(
            supportedNetworkTypes: Chain.allCases,
            defaultNetwork: defaultChain
        )
        return createView(for: wireframe, interactor: interactor)
    }

    static func createViewForConnection(item: ConnectionItem) -> UsernameSetupViewProtocol? {
        let wireframe = SelectConnection.UsernameSetupWireframe(connectionItem: item)
        let interactor = UsernameSetupInteractor(
            supportedNetworkTypes: [item.type.chain],
            defaultNetwork: item.type.chain
        )

        return createView(for: wireframe, interactor: interactor)
    }

    static func createViewForSwitch() -> UsernameSetupViewProtocol? {
        let defaultChain = SettingsManager.shared.selectedConnection.type.chain

        let wireframe = SwitchAccount.UsernameSetupWireframe()
        let interactor = UsernameSetupInteractor(
            supportedNetworkTypes: Chain.allCases,
            defaultNetwork: defaultChain
        )

        return createView(for: wireframe, interactor: interactor)
    }

    private static func createView(
        for wireframe: UsernameSetupWireframeProtocol,
        interactor: UsernameSetupInteractor
    ) -> UsernameSetupViewProtocol? {
        let view = UsernameSetupViewController(nib: R.nib.usernameSetupViewController)
        let presenter = UsernameSetupPresenter()

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared
        presenter.localizationManager = LocalizationManager.shared

        return view
    }
}
