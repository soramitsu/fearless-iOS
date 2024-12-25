import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore
import SSFModels

enum AccountCreateEcosystem {
    case regular
    case ton
}

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(
        ecosystem: AccountCreateEcosystem,
        model: UsernameSetupModel,
        flow: AccountCreateFlow
    ) -> AccountCreateViewProtocol? {
        let wireframe = AccountCreateWireframe()

        return createViewForUsername(
            ecosystem: ecosystem,
            model: model,
            flow: flow,
            wireframe: wireframe
        )
    }

    static func createViewForAdding(
        ecosystem: AccountCreateEcosystem,
        model: UsernameSetupModel
    ) -> AccountCreateViewProtocol? {
        let wireframe = AddAccount.AccountCreateWireframe()

        return createViewForUsername(
            ecosystem: ecosystem,
            model: model,
            flow: .wallet,
            wireframe: wireframe
        )
    }

    static func createViewForSwitch(
        ecosystem: AccountCreateEcosystem,
        model: UsernameSetupModel
    ) -> AccountCreateViewProtocol? {
        let wireframe = SwitchAccount.AccountCreateWireframe()
        return createViewForUsername(
            ecosystem: ecosystem,
            model: model,
            flow: .wallet,
            wireframe: wireframe
        )
    }

    static func createViewForUsername(
        ecosystem: AccountCreateEcosystem,
        model: UsernameSetupModel,
        flow: AccountCreateFlow,
        wireframe: AccountCreateWireframeProtocol
    ) -> AccountCreateViewProtocol? {
        let interactor = AccountCreateInteractor(ecosystem: ecosystem, mnemonicCreator: IRMnemonicCreator())
        let presenter = AccountCreatePresenter(
            ecosystem: ecosystem,
            usernameSetup: model,
            wireframe: wireframe,
            interactor: interactor,
            flow: flow
        )
        let view = AccountCreateViewController(ecosystem: ecosystem, presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
