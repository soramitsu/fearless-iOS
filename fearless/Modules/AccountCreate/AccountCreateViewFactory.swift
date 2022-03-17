import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(
        model: UsernameSetupModel,
        chainType: AccountCreateChainType
    ) -> AccountCreateViewProtocol? {
        let wireframe = AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            chainType: chainType,
            wireframe: wireframe
        )
    }

    static func createViewForAdding(
        model: UsernameSetupModel,
        chainType: AccountCreateChainType
    ) -> AccountCreateViewProtocol? {
        let wireframe = AddAccount.AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            chainType: chainType,
            wireframe: wireframe
        )
    }

    static func createViewForSwitch(
        model: UsernameSetupModel,
        chainType: AccountCreateChainType
    ) -> AccountCreateViewProtocol? {
        let wireframe = SwitchAccount.AccountCreateWireframe()
        return createViewForUsername(
            model: model,
            chainType: chainType,
            wireframe: wireframe
        )
    }

    static func createViewForUsername(
        model: UsernameSetupModel,
        chainType: AccountCreateChainType,
        wireframe: AccountCreateWireframeProtocol
    ) -> AccountCreateViewProtocol? {
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())
        let presenter = AccountCreatePresenter(
            usernameSetup: model,
            chainType: chainType,
            wireframe: wireframe,
            interactor: interactor
        )
        let view = AccountCreateViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
