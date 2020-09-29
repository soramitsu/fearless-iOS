import UIKit
import SoraUI
import CommonWallet

final class WalletAmountView: WalletFormItemView {
    @IBOutlet private var borderView: BorderedContainerView!
    @IBOutlet private var fieldBackgroundView: TriangularedView!
    @IBOutlet private var animatedTextField: AnimatedTextField!

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 84.0)
    }
}

extension WalletAmountView {
    var borderType: BorderType {
        get {
            borderView.borderType
        }

        set {
            borderView.borderType = newValue
        }
    }

    func bind(viewModel: WalletFormSpentAmountModel) {
        animatedTextField.title = viewModel.title
        animatedTextField.text = viewModel.amount
        animatedTextField.isUserInteractionEnabled = false

        fieldBackgroundView.applyDisabledStyle()
    }
}
