import UIKit
import CommonWallet
import SoraUI

final class WalletTransferTokenView: WalletBaseTokenView {
    weak var delegate: SelectedAssetViewDelegate?

    private(set) var viewModel: WalletTokenViewModel?

    var activated: Bool {
        actionControl.isActivated
    }

    override func actionBalance() {
        try? viewModel?.detailsCommand?.execute()
    }
}

extension WalletTransferTokenView: SelectedAssetViewProtocol {
    func bind(viewModel: AssetSelectionViewModelProtocol) {
        self.viewModel = viewModel as? WalletTokenViewModel

        iconImageView.image = viewModel.icon

        actionControl.titleLabel.text = viewModel.title
        balanceTitle.text = viewModel.subtitle.uppercased() + ":"
        balanceDetails.text = viewModel.details

        actionControl.isUserInteractionEnabled = false

        tokenBackgroundView.applyEnabledStyle()
    }
}
