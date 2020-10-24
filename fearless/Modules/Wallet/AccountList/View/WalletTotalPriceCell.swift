import UIKit
import SoraUI
import CommonWallet

final class WalletTotalPriceCell: UICollectionViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var priceLabel: UILabel!
    @IBOutlet private var accountButton: RoundedButton!

    var viewModel: WalletViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()

        (viewModel as? WalletTotalPriceViewModel)?.imageViewModel?.cancel()
    }

    @IBAction private func actionAccount() {
        try? (viewModel as? WalletTotalPriceViewModel)?.accountCommand?.execute()
    }
}

extension WalletTotalPriceCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let totalPriceViewModel = viewModel as? WalletTotalPriceViewModel {
            self.viewModel = totalPriceViewModel

            titleLabel.text = totalPriceViewModel.details
            priceLabel.text = totalPriceViewModel.amount

            accountButton.imageWithTitleView?.iconImage = nil

            totalPriceViewModel.imageViewModel?.loadImage { [weak self] (image, _)  in
                self?.accountButton.imageWithTitleView?.iconImage = image
            }
        }
    }
}
