import Foundation
import SoraFoundation

final class StakingAmountWireframe: StakingAmountWireframeProtocol {
    func presentAccountSelection(
        _ accounts: [ChainAccountResponse],
        selectedAccountItem: ChainAccountResponse,
        delegate: ModalPickerViewControllerDelegate,
        from view: StakingAmountViewProtocol?,
        context: AnyObject?
    ) {
        let title = LocalizableResource { locale in
            R.string.localizable
                .stakingRewardPayoutAccount(preferredLanguages: locale.rLanguages)
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

    func proceed(
        from view: StakingAmountViewProtocol?,
        state: InitiatedBonding,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let validatorsView = SelectValidatorsStartViewFactory.createInitiatedBondingView(
            selectedAccount: selectedAccount,
            asset: asset,
            chain: chain,
            state: state
        )
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
