import UIKit
import CommonWallet
import SoraUI

class WalletBaseTokenView: UIControl {
    var borderType: BorderType {
        get {
            borderedView.borderType
        }
        set(newValue) {
            borderedView.borderType = newValue
        }
    }

    @IBOutlet private(set) var borderedView: BorderedContainerView!
    @IBOutlet private(set) var borderedActionControl: BorderedSubtitleActionView!
    @IBOutlet private(set) var balanceTitle: UILabel!
    @IBOutlet private(set) var balanceDetails: UILabel!
    @IBOutlet private(set) var contentView: UIView!

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 102.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupSubviews()
    }

    func setupSubviews() {
        _ = R.nib.walletTokenView(owner: self)
        addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        contentView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    }

    @IBAction func actionBalance() {}
}
