import Foundation
import CommonWallet

final class WalletFearlessDefinition: WalletFearlessFormDefining {
    let binder: WalletFormViewModelBinderProtocol
    let itemViewFactory: WalletFormItemViewFactoryProtocol

    init(binder: WalletFormViewModelBinderProtocol, itemViewFactory: WalletFormItemViewFactoryProtocol) {
        self.binder = binder
        self.itemViewFactory = itemViewFactory
    }

    func defineViewForSpentAmountModel(_ model: WalletFormSpentAmountModel) -> WalletFormItemView? {
        let amountView = WalletDisplayAmountView()
        amountView.bind(viewModel: model)
        return amountView
    }

    func defineViewForFearlessTokenViewModel(_ model: WalletTokenViewModel) -> WalletFormItemView? {
        let assetView = WalletDisplayTokenView()
        assetView.bind(viewModel: model)
        return assetView
    }

    func defineViewForCompoundDetails(_ viewModel: WalletCompoundDetailsViewModel) -> WalletFormItemView? {
        let detailsView = R.nib.walletCompoundDetailsView(owner: nil)!
        detailsView.bind(viewModel: viewModel)
        return detailsView
    }
}
