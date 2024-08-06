import Foundation
import IrohaCrypto
import SSFModels

final class AccountImportWireframe: AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showEthereumStep(from view: AccountImportViewProtocol?, with data: AccountCreationStep.SubstrateStepData) {
        guard let ethereumStep = AccountImportViewFactory.createViewForOnboarding(
            defaultSource: .mnemonic,
            flow: .wallet(step: .ethereum(data: data))
        ) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(ethereumStep.controller, animated: true)
        }
    }

    func proceed(from view: AccountImportViewProtocol?, flow: AccountImportFlow) {
        switch flow {
        case .wallet:
            guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
                return
            }
            rootAnimator.animateTransition(to: pincodeViewController)
        case .chain:
            dismiss(view: view)
        }
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
