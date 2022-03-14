import Foundation
import IrohaCrypto

extension AddAccount {
    final class AccountCreateWireframe: AccountCreateWireframeProtocol {
        func confirm(
            from view: NewAccountCreateViewProtocol?,
            request: MetaAccountCreationRequest,
            mnemonic: [String]
        ) {
            guard let accountConfirmation = AccountConfirmViewFactory
                .createViewForAdding(request: request, mnemonic: mnemonic)?.controller
            else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(accountConfirmation, animated: true)
            }
        }

        func presentCryptoTypeSelection(
            from view: NewAccountCreateViewProtocol?,
            availableTypes: [CryptoType],
            selectedType: CryptoType,
            delegate: ModalPickerViewControllerDelegate?,
            context: AnyObject?
        ) {
            guard let modalPicker = ModalPickerFactory.createPickerForList(
                availableTypes,
                selectedType: selectedType,
                delegate: delegate,
                context: context
            ) else {
                return
            }

            view?.controller.navigationController?.present(
                modalPicker,
                animated: true,
                completion: nil
            )
        }
    }
}
