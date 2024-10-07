import Foundation

extension AddAccount {
    final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
        func proceed(
            from view: UsernameSetupViewProtocol?,
            flow _: AccountCreateFlow = .wallet,
            model: UsernameSetupModel,
            ecosystem: AccountCreateEcosystem
        ) {
            guard let accountCreation = AccountCreateViewFactory.createViewForAdding(ecosystem: ecosystem, model: model) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                accountCreation.controller,
                animated: true
            )
        }
    }
}
