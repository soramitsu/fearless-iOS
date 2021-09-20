import UIKit
import SoraUI
import CommonWallet

final class WalletDisplayAmountView: WalletBaseAmountView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 116.0)
    }
}

extension WalletDisplayAmountView: WalletFormBordering {
    var borderType: BorderType {
        get {
            borderView.borderType
        }
        set(newValue) {
            borderView.borderType = newValue
        }
    }

    func bind(viewModel: WalletFormSpentAmountModel) {
        amountInputView.titleLabel.text = viewModel.title
        amountInputView.textField.text = viewModel.amount
        amountInputView.isUserInteractionEnabled = false

        fieldBackgroundView.applyDisabledStyle()

        if let model = viewModel as? RichAmountDisplayViewModelProtocol {
            amountInputView.assetIcon = model.icon
            amountInputView.symbol = model.symbol
        }
    }
}

protocol RichAmountDisplayViewModelProtocol: WalletFormViewBindingProtocol, AssetBalanceViewModelProtocol {}

final class RichAmountDisplayViewModel: RichAmountDisplayViewModelProtocol {
    let displayViewModel: WalletFormSpentAmountModel

    let icon: UIImage?
    let symbol: String
    let balance: String?
    let price: String?

    var title: String {
        displayViewModel.title
    }

    var amount: String {
        displayViewModel.amount
    }

    init(
        displayViewModel: WalletFormSpentAmountModel,
        icon: UIImage?,
        symbol: String,
        balance: String?,
        price: String?
    ) {
        self.displayViewModel = displayViewModel
        self.icon = icon
        self.symbol = symbol
        self.balance = balance
        self.price = price
    }

    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        displayViewModel.accept(definition: definition)
    }
}
