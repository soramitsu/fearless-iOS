import Foundation
import SoraFoundation

final class StakingAmountWireframe: StakingAmountWireframeProtocol {
    func presentAccountSelection(_ accounts: [AccountItem],
                                 selectedAccountItem: AccountItem,
                                 delegate: ModalPickerViewControllerDelegate,
                                 from view: StakingAmountViewProtocol?,
                                 context: AnyObject?) {
        let title = LocalizableResource { locale in
            R.string.localizable
                .stakingRewardPayoutAccount(preferredLanguages: locale.rLanguages)
        }

        guard let picker = ModalPickerFactory.createPickerList(accounts,
                                                               selectedAccount: selectedAccountItem,
                                                               title: title,
                                                               delegate: delegate,
                                                               context: context) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    func presentNotEnoughFunds(from view: StakingAmountViewProtocol?) {
        let languages = view?.localizationManager?.selectedLocale.rLanguages
        let message = R.string.localizable
            .stakingAmountTooBigError(preferredLanguages: languages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: languages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func close(view: StakingAmountViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
