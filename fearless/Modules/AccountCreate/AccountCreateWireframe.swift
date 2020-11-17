import Foundation
import IrohaCrypto

final class AccountCreateWireframe: AccountCreateWireframeProtocol {
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata) {
        guard let accountConfirmation = AccountConfirmViewFactory
            .createViewForOnboarding(request: request, metadata: metadata)?.controller else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(accountConfirmation, animated: true)
        }
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
                                     availableTypes: [Chain],
                                     selectedType: Chain,
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
