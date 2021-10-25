import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            wireframe: wireframe
        )
    }

    static func createViewForAdding(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = AddAccount.AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            wireframe: wireframe
        )
    }

    static func createViewForSwitch(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = SwitchAccount.AccountCreateWireframe()
        return createViewForUsername(model: model, wireframe: wireframe)
    }

    static func createViewForUsername(
        model: UsernameSetupModel,
        wireframe: AccountCreateWireframeProtocol
    ) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(usernameSetup: model)

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())

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
