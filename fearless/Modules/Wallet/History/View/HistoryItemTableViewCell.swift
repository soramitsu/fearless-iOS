import UIKit
import CommonWallet

final class HistoryItemTableViewCell: UITableViewCell {
    private enum Constants {
        static let trailingWithoutStatus: CGFloat = 12.0
        static let trailingWithStatus: CGFloat = 36.0
    }

    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var amountLabel: UILabel!
    @IBOutlet private var statusImageView: UIImageView!
    @IBOutlet private var trailingConstraint: NSLayoutConstraint!

    var viewModel: WalletViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()

        (viewModel as? HistoryItemViewModel)?.imageViewModel?.cancel()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }
}

extension HistoryItemTableViewCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let itemViewModel = viewModel as? HistoryItemViewModel {
            self.viewModel = viewModel

            titleLabel.text = itemViewModel.title
            detailsLabel.text = itemViewModel.details

            switch itemViewModel.direction {
            case .incoming, .reward:
                amountLabel.text = "+ \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorGreen()!
            case .outgoing, .slash:
                amountLabel.text = "- \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorWhite()!
            }

            switch itemViewModel.status {
            case .commited:
                statusImageView.isHidden = true
                trailingConstraint.constant = Constants.trailingWithoutStatus
            case .rejected:
                statusImageView.isHidden = false
                statusImageView.image = R.image.iconTxFailed()
                amountLabel.textColor = R.color.colorGray()!
                trailingConstraint.constant = Constants.trailingWithStatus
            case .pending:
                statusImageView.isHidden = false
                statusImageView.image = R.image.iconTxPending()
                amountLabel.textColor = R.color.colorWhite()
                trailingConstraint.constant = Constants.trailingWithStatus
            }

            iconImageView.image = nil

            itemViewModel.imageViewModel?.loadImage { [weak self] image, _ in
                self?.iconImageView.image = image
            }
        }
    }
}
