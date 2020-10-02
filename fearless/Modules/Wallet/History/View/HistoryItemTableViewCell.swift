import UIKit
import CommonWallet

final class HistoryItemTableViewCell: UITableViewCell {
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var amountLabel: UILabel!
    @IBOutlet private var statusImageView: UIImageView!

    var viewModel: WalletViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()

        (viewModel as? HistoryItemViewModel)?.imageViewModel.cancel()
    }
}

extension HistoryItemTableViewCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let itemViewModel = viewModel as? HistoryItemViewModel {
            self.viewModel = viewModel

            titleLabel.text = itemViewModel.title
            detailsLabel.text = itemViewModel.details

            switch itemViewModel.direction {
            case .incoming:
                amountLabel.text = "+ \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorGreen()!
            case .outgoing:
                amountLabel.text = "- \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorWhite()!
            }

            iconImageView.image = nil

            itemViewModel.imageViewModel.loadImage { [weak self] (image, _) in
                self?.iconImageView.image = image
            }
        }
    }
}
