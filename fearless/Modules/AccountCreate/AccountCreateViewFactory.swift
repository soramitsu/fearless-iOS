import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(username: String) -> AccountCreateViewProtocol? {
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: ConnectionItem.defaultConnection.type.chain)
        let wireframe = AccountCreateWireframe()

        return createViewForUsername(username,
                                     interactor: interactor,
                                     wireframe: wireframe)
    }

    static func createViewForAdding(username: String) -> AccountCreateViewProtocol? {
        let defaultAddressType = SettingsManager.shared.selectedConnection.type

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: defaultAddressType.chain)
        let wireframe = AddCreationWireframe()

        return createViewForUsername(username,
                                     interactor: interactor,
                                     wireframe: wireframe)
    }

    static func createViewForConnection(item: ConnectionItem,
                                        username: String) -> AccountCreateViewProtocol? {
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: [item.type.chain],
                                                 defaultNetwork: item.type.chain)

        let wireframe = ConnectionAccountCreateWireframe(connectionItem: item)

        return createViewForUsername(username,
                                     interactor: interactor,
                                     wireframe: wireframe)
    }

    static func createViewForSwitch(username: String) -> AccountCreateViewProtocol? {
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: ConnectionItem.defaultConnection.type.chain)
        let wireframe = ChangeCreationWireframe()

        return createViewForUsername(username,
                                     interactor: interactor,
                                     wireframe: wireframe)
    }

    static func createViewForUsername(_ username: String,
                                      interactor: AccountCreateInteractor,
                                      wireframe: AccountCreateWireframeProtocol)
    -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
