import Foundation
import SoraFoundation

final class StakingRewardDestSetupWireframe: StakingRewardDestSetupWireframeProtocol {
    func presentAccountSelection(
        _ accounts: [AccountItem],
        selectedAccountItem: AccountItem,
        delegate: ModalPickerViewControllerDelegate,
        from view: StakingRewardDestSetupViewProtocol?,
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

    func proceed(view _: StakingRewardDestSetupViewProtocol?) {
        // TODO: FLW-769 https://soramitsu.atlassian.net/browse/FLW-769
        //        guard let confirmationView = StakingRewardDestConfirmViewFactory.createView(from: amount) else {
        //            return
        //        }
        //
        //        view?.controller.navigationController?.pushViewController(
        //            confirmationView.controller,
        //            animated: true
        //        )
        //    }
    }
}
