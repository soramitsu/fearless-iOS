import Foundation
import SSFModels

extension SwitchAccount {
    final class AccountImportWireframe: AccountImportWireframeProtocol {
        func showEthereumStep(from _: AccountImportViewProtocol?, with _: AccountCreationStep.SubstrateStepData) {}

        func proceed(from view: AccountImportViewProtocol?, flow _: AccountImportFlow) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }

        func presentSourceTypeSelection(
            from view: AccountImportViewProtocol?,
            availableSources: [AccountImportSource],
            selectedSource: AccountImportSource,
            delegate: ModalPickerViewControllerDelegate?,
            context: AnyObject?
        ) {
            guard let modalPicker = ModalPickerFactory.createPickerForList(
                availableSources,
                selectedType: selectedSource,
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

        func presentCryptoTypeSelection(
            from view: AccountImportViewProtocol?,
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
