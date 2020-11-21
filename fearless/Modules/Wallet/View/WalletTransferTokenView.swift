import UIKit
import CommonWallet
import SoraUI

final class WalletTransferTokenView: WalletBaseTokenView {
    weak var delegate: SelectedAssetViewDelegate?

    private(set) var viewModel: WalletTokenViewModel?

    var activated: Bool {
        borderedActionControl.actionControl.isActivated
    }

    override func actionBalance() {
        try? viewModel?.detailsCommand?.execute()
    }
}

extension WalletTransferTokenView: SelectedAssetViewProtocol {
    func bind(viewModel: AssetSelectionViewModelProtocol) {
        guard let viewModel = viewModel as? WalletTokenViewModel else {
            return
        }

        self.viewModel = viewModel

        borderedActionControl.actionControl.contentView.titleLabel.text = viewModel.header
        borderedActionControl.actionControl.contentView.subtitleImageView.image = viewModel.icon
        borderedActionControl.actionControl.contentView.subtitleLabelView.text = viewModel.title

        balanceTitle.text = viewModel.subtitle.uppercased() + ":"
        balanceDetails.text = viewModel.details

        borderedActionControl.isUserInteractionEnabled = false

        borderedActionControl.applyDisabledStyle()
    }
}
