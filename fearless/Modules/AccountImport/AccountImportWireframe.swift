import Foundation
import IrohaCrypto

final class AccountImportWireframe: AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from _: AccountImportViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
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
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
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

    func presentNetworkTypeSelection(
        from view: AccountImportViewProtocol?,
        availableTypes: [Chain],
        selectedType: Chain,
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
