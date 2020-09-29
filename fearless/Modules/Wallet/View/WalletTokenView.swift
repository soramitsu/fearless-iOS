import UIKit
import CommonWallet
import SoraUI

final class WalletTokenView: UIView {
    var style: WalletFormTokenViewStyle?

    @IBOutlet private var borderedView: BorderedContainerView!
    @IBOutlet private var tokenBackgroundView: TriangularedView!
    @IBOutlet private var actionControl: ActionTitleControl!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var balanceTitle: UILabel!
    @IBOutlet private var balanceDetails: UILabel!

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 102.0)
    }

    @IBAction private func actionBalance() {}
}

extension WalletTokenView: WalletFormTokenViewProtocol {

    func bind(viewModel: WalletFormTokenViewModel) {
        iconImageView.image = viewModel.icon

        actionControl.titleLabel.text = viewModel.title
        balanceDetails.text = viewModel.subtitle
    }
}

extension WalletTokenView: WalletFormBordering {
    var borderType: BorderType {
        get { borderedView.borderType }
        set {
            borderedView.borderType = newValue
        }
    }
}
