import Foundation
import IrohaCrypto

final class AddImportedWireframe: AccountImportWireframeProtocol {
    func proceed(from view: AccountImportViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainIfExists(tabBarController: navigationController.tabBarController,
                                                   closing: navigationController,
                                                   animated: true)
    }

    func presentSourceTypeSelection(from view: AccountImportViewProtocol?,
                                    availableSources: [AccountImportSource],
                                    selectedSource: AccountImportSource,
                                    delegate: ModalPickerViewControllerDelegate?,
                                    context: AnyObject?) {
        guard let modalPicker = ModalPickerFactory.createPickerForList(availableSources,
                                                                       selectedType: selectedSource,
                                                                       delegate: delegate,
                                                                       context: context) else {
            return
        }

        view?.controller.navigationController?.present(modalPicker,
                                                       animated: true,
                                                       completion: nil)
    }

    func presentCryptoTypeSelection(from view: AccountImportViewProtocol?,
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

    func presentAddressTypeSelection(from view: AccountImportViewProtocol?,
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
