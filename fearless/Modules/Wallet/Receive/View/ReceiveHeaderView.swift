import Foundation
import CommonWallet

final class ReceiveHeaderView: UIView {
    @IBOutlet private(set) var accountView: DetailsTriangularedView!
    @IBOutlet private(set) var infoLabel: UILabel!

    var actionCommand: WalletCommandProtocol?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 144.0)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        accountView.addTarget(self, action: #selector(actionReceive), for: .touchUpInside)
    }

    @objc func actionReceive() {
        try? actionCommand?.execute()
    }
}
