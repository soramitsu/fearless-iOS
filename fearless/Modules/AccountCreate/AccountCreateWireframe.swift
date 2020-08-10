import Foundation
import IrohaCrypto

final class AccountCreateWireframe: AccountCreateWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from view: AccountCreateViewProtocol?) {
        guard let accountConfirmation = AccountConfirmViewFactory.createView()?.controller else {
            return
        }

        let navigationController = FearlessNavigationController()
        navigationController.viewControllers = [accountConfirmation]

        rootAnimator.animateTransition(to: navigationController)
    }

    func presentCryptoTypeSelection(from view: AccountCreateViewProtocol?,
                                    availableTypes: [CryptoType],
                                    selectedType: CryptoType,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?) {
        guard let modalPicker = ModalPickerFactory.createPickerForList(availableTypes,
                                                                       selectedType: selectedType,
                                                                       delegate: delegate,
                                                                       context: context) else {
            return
        }

        view?.controller.navigationController?.present(modalPicker,
                                                       animated: true,
                                                       completion: nil)
    }

    func presentNetworkTypeSelection(from view: AccountCreateViewProtocol?,
                                     availableTypes: [SNAddressType],
                                     selectedType: SNAddressType,
                                     delegate: ModalPickerViewControllerDelegate?,
                                     context: AnyObject?) {
        guard let modalPicker = ModalPickerFactory.createPickerForList(availableTypes,
                                                                       selectedType: selectedType,
                                                                       delegate: delegate,
                                                                       context: context) else {
            return
        }

        view?.controller.navigationController?.present(modalPicker,
                                                       animated: true,
                                                       completion: nil)
    }
}
