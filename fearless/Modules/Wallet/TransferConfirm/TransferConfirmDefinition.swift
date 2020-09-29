import Foundation
import CommonWallet

final class TransferConfirmDefinition: WalletFormDefining {
    let binder: WalletFormViewModelBinderProtocol
    let itemViewFactory: WalletFormItemViewFactoryProtocol

    init(binder: WalletFormViewModelBinderProtocol, itemViewFactory: WalletFormItemViewFactoryProtocol) {
        self.binder = binder
        self.itemViewFactory = itemViewFactory
    }

    func defineViewForSpentAmountModel(_ model: WalletFormSpentAmountModel) -> WalletFormItemView? {
        let amountView = R.nib.walletAmountView(owner: nil)
        amountView?.bind(viewModel: model)
        return amountView
    }

    func defineViewForMultilineTitleIconModel(_ model: MultilineTitleIconViewModel) -> WalletFormItemView? {
        let receiverView = R.nib.walletReceiverView(owner: nil)
        receiverView?.bind(viewModel: model)
        return receiverView
    }
}
