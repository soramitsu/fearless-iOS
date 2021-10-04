import Foundation
import CommonWallet
import SoraFoundation

final class WalletFearlessDefinition: WalletFearlessFormDefining {
    let binder: WalletFormViewModelBinderProtocol
    let itemViewFactory: WalletFormItemViewFactoryProtocol

    init(
        binder: WalletFormViewModelBinderProtocol,
        itemViewFactory: WalletFormItemViewFactoryProtocol
    ) {
        self.binder = binder
        self.itemViewFactory = itemViewFactory
    }

    func defineViewForFearlessTokenViewModel(_: WalletTokenViewModel) -> WalletFormItemView? {
        nil
    }

    func defineViewForCompoundDetails(_ viewModel: WalletCompoundDetailsViewModel) -> WalletFormItemView? {
        let detailsView = R.nib.walletCompoundDetailsView(owner: nil)!
        detailsView.bind(viewModel: viewModel)
        detailsView.contentInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 12.0, right: 0.0)
        return detailsView
    }

    func defineViewForAmountDisplay(
        _ viewModel: RichAmountDisplayViewModel) -> WalletFormItemView? {
        let amountDisplayView = WalletDisplayAmountView()
        amountDisplayView.bind(viewModel: viewModel)
        return amountDisplayView
    }
}
