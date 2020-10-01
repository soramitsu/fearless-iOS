import UIKit
import CommonWallet

final class WalletAssetCell: UICollectionViewCell {
    @IBOutlet private var iconView: UIImageView!
    @IBOutlet private var platformLabel: UILabel!
    @IBOutlet private var symbolLabel: UILabel!
    @IBOutlet private var balanceLabel: UILabel!
    @IBOutlet private var priceLabel: UILabel!
    @IBOutlet private var changeLabel: UILabel!
    @IBOutlet private var totalPriceLabel: UILabel!
    @IBOutlet private var triangualedView: TriangularedView!

    var viewModel: WalletViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()

        (viewModel as? WalletAssetViewModel)?.imageViewModel?.cancel()
    }
}

extension WalletAssetCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let assetViewModel = viewModel as? WalletAssetViewModel {
            self.viewModel = viewModel

            platformLabel.text = assetViewModel.platform
            symbolLabel.text = assetViewModel.symbol
            balanceLabel.text = assetViewModel.amount
            priceLabel.text = assetViewModel.details
            totalPriceLabel.text = assetViewModel.accessoryDetails

            switch assetViewModel.priceChangeViewModel {
            case .up(let displayString):
                changeLabel.text = displayString
                changeLabel.textColor = R.color.colorGreen()!
            case .down(let displayString):
                changeLabel.text = displayString
                changeLabel.textColor = R.color.colorRed()!
            }

            iconView.image = nil

            assetViewModel.imageViewModel?.loadImage { [weak self] (image, _)  in
                self?.iconView.image = image
            }
        }
    }
}
