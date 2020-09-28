import UIKit
import CommonWallet
import SoraUI

final class WalletReceiverView: WalletFormItemView {
    @IBOutlet private var borderView: BorderedContainerView!
    @IBOutlet private var iconView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 68.0)
    }

    @IBAction private func actionCopy() {}
}

extension WalletReceiverView {
    var borderType: BorderType {
        get {
            borderView.borderType
        }

        set {
            borderView.borderType = newValue
        }
    }

    func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        iconView.image = viewModel.icon
        titleLabel.text = viewModel.text
    }
}
