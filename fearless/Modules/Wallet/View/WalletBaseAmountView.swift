import Foundation
import CommonWallet
import SoraUI

class WalletBaseAmountView: UIView {
    @IBOutlet private(set) var borderView: BorderedContainerView!
    @IBOutlet private(set) var fieldBackgroundView: TriangularedView!
    @IBOutlet private(set) var animatedTextField: AnimatedTextField!
    @IBOutlet private(set) var contentView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupSubviews()
    }

    func setupSubviews() {
        _ = R.nib.walletAmountView(owner: self)
        addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        contentView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    }
}
