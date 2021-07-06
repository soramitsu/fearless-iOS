import Foundation
import SoraFoundation

final class StakingAmountWireframe: StakingAmountWireframeProtocol {
    func presentAccountSelection(
        _ accounts: [AccountItem],
        selectedAccountItem: AccountItem,
        delegate: ModalPickerViewControllerDelegate,
        from view: StakingAmountViewProtocol?,
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

    func proceed(from view: StakingAmountViewProtocol?, state: InitiatedBonding) {
        guard let validatorsView = SelectValidatorsStartViewFactory
            .createInitiatedBondingView(with: state)
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorsView.controller,
            animated: true
        )
    }

    func close(view: StakingAmountViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
