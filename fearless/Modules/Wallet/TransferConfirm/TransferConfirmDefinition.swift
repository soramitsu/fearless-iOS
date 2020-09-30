import Foundation
import CommonWallet

final class TransferConfirmDefinition: WalletFearlessFormDefining {
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

    func defineViewForFearlessAccountViewModel(_ model: WalletAccountViewModel) -> WalletFormItemView? {
        let receiverView = WalletDisplayReceiverView()
        receiverView.bind(viewModel: model)
        return receiverView
    }
}
