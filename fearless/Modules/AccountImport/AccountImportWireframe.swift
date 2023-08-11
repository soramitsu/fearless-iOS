import Foundation
import IrohaCrypto

final class AccountImportWireframe: AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showSecondStep(from view: AccountImportViewProtocol?, with data: AccountCreationStep.FirstStepData) {
        guard let secondStep = AccountImportViewFactory.createViewForOnboarding(
            defaultSource: .mnemonic,
            flow: .wallet(step: .second(data: data))
        ) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(secondStep.controller, animated: true)
        }
    }

    func proceed(from _: AccountImportViewProtocol?, flow: AccountImportFlow) {
        switch flow {
        case .wallet:
            guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
                return
            }
            rootAnimator.animateTransition(to: pincodeViewController)
        case .chain:
            DispatchQueue.main.async {
//                guard let topViewController = UIApplication.topViewController() else {
                UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true)
//                    return
//                }
//
//                if topViewController.navigationController != nil {
//                    topViewController.navigationController?.popToRootViewController(animated: true)
//                } else {
//                MainTransitionHelper.transitToMainTabBarController(closing: topViewController, animated: true)
//                }
            }
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
