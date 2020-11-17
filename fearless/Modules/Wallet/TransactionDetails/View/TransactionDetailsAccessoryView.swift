import UIKit
import CommonWallet

final class TransactionDetailsAccessoryView: UIView {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var amountLabel: UILabel!
    @IBOutlet private var detailsView: DetailsTriangularedView!

    private var viewModel: TransactionDetailsAccessoryViewModel?

    override func awakeFromNib() {
        super.awakeFromNib()

        detailsView.titleLabel.lineBreakMode = .byTruncatingMiddle

        detailsView.addTarget(self, action: #selector(actionDetails), for: .touchUpInside)
    }

    @objc private func actionDetails() {
        try? viewModel?.command.execute()
    }
}

extension TransactionDetailsAccessoryView: CommonWallet.AccessoryViewProtocol {
    var contentView: UIView {
        self
    }

    var isActionEnabled: Bool {
        get {
            detailsView.isUserInteractionEnabled
        }

        set(newValue) {
            detailsView.isUserInteractionEnabled = newValue
        }
    }

    var extendsUnderSafeArea: Bool { true }

    func bind(viewModel: AccessoryViewModelProtocol) {
        if let viewModel = viewModel as? TransactionDetailsAccessoryViewModel {
            self.viewModel = viewModel

            titleLabel.text = viewModel.title
            amountLabel.text = viewModel.amount

            detailsView.title = viewModel.action
            detailsView.iconImage = viewModel.icon
        }
    }
}
