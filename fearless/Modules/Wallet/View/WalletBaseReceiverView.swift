import UIKit
import CommonWallet
import SoraUI

class WalletBaseReceiverView: UIView {
    var borderType: BorderType {
        get {
            borderView.borderType
        }

        set {
            borderView.borderType = newValue
        }
    }

    @IBOutlet private(set) var borderView: BorderedContainerView!
    @IBOutlet private(set) var iconView: UIImageView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var contentView: UIView!

    var viewModel: WalletAccountViewModel?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 68.0)
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
        _ = R.nib.walletReceiverView(owner: self)
        addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        contentView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    }

    @IBAction func actionCopy() {
        try? viewModel?.copyCommand.execute()
    }
}
