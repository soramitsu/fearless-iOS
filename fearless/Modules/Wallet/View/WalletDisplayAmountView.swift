import UIKit
import SoraUI
import CommonWallet

final class WalletDisplayAmountView: WalletBaseAmountView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 84.0)
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
        richTextField.titleLabel.text = viewModel.title
        richTextField.textField.text = viewModel.amount
        richTextField.isUserInteractionEnabled = false

//        fieldBackgroundView.applyDisabledStyle()
    }
}
