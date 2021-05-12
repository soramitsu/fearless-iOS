import Foundation
import SoraFoundation

final class ControllerAccountWireframe: ControllerAccountWireframeProtocol {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        stashAccountItem: AccountItem,
        controllerAccountItem: AccountItem
    ) {
        guard let confirmation = ControllerAccountConfirmationViewFactory.createView(
            stashAccountItem: stashAccountItem,
            controllerAccountItem: controllerAccountItem
        ) else { return }
        view?.controller.navigationController?.pushViewController(confirmation.controller, animated: true)
    }

    func presentAccountSelection(
        _ accounts: [AccountItem],
        selectedAccountItem: AccountItem,
        delegate: ModalPickerViewControllerDelegate,
        from view: ControllerBackedProtocol?,
        context: AnyObject?
    ) {
        let title = LocalizableResource { locale in
            R.string.localizable
                .stakingRewardDestinationTitle(preferredLanguages: locale.rLanguages)
        }

        guard let picker = ModalPickerFactory.createPickerList(
            accounts,
            selectedAccount: selectedAccountItem,
            title: title,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
