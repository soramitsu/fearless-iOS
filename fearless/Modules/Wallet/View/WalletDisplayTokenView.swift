import Foundation
import CommonWallet
import SoraUI

final class WalletDisplayTokenView: WalletBaseTokenView {
    var style: WalletFormTokenViewStyle?

    private(set) var viewModel: WalletTokenViewModel?

    override func actionBalance() {
        try? viewModel?.detailsCommand?.execute()
    }
}

extension WalletDisplayTokenView {
    func bind(viewModel: WalletTokenViewModel) {
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

extension WalletDisplayTokenView: WalletFormBordering {}
