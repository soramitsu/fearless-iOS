import Foundation
import IrohaCrypto

final class NetworkManagementWireframe: NetworkManagementWireframeProtocol {

    func presentAccountSelection(_ accounts: [AccountItem],
                                 addressType: SNAddressType,
                                 delegate: ModalPickerViewControllerDelegate,
                                 from view: NetworkManagementViewProtocol?,
                                 context: AnyObject?) {
        guard let picker = ModalPickerFactory.createPickerList(accounts,
                                                               selectedAccount: nil,
                                                               addressType: addressType,
                                                               delegate: delegate,
                                                               context: context) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    func presentAccountCreation(for connection: ConnectionItem,
                                from view: NetworkManagementViewProtocol?) {
        guard
            let accountView = OnboardingMainViewFactory.createViewForConnection(item: connection),
            let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.pushViewController(accountView.controller, animated: true)
    }

    func presentConnectionInfo(_ connectionItem: ConnectionItem,
                               mode: NetworkInfoMode,
                               from view: NetworkManagementViewProtocol?) {
        guard let networkInfoView = NetworkInfoViewFactory.createView(with: connectionItem,
                                                                      mode: mode) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: networkInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func presentConnectionAdd(from view: NetworkManagementViewProtocol?) {
        guard let addConnectionView = AddConnectionViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(addConnectionView.controller,
                                                                  animated: true)
    }

    func complete(from view: NetworkManagementViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(closing: navigationController,
                                                           animated: true)
    }
}
