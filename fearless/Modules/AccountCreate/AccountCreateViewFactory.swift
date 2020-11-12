import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(username: String) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedAddressTypes: SNAddressType.supported,
                                                 defaultAddressType: ConnectionItem.defaultConnection.type)
        let wireframe = AccountCreateWireframe()

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

    static func createViewForAdding(username: String) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        let defaultAddressType = SettingsManager.shared.selectedConnection.type

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedAddressTypes: SNAddressType.supported,
                                                 defaultAddressType: defaultAddressType)
        let wireframe = AddCreationWireframe()

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

    static func createViewForConnection(item: ConnectionItem,
                                        username: String) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedAddressTypes: [item.type],
                                                 defaultAddressType: item.type)

        let wireframe = ConnectionAccountCreateWireframe(connectionItem: item)

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
