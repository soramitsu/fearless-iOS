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

        iconImageView.image = viewModel.icon

        actionControl.titleLabel.text = viewModel.title
        balanceTitle.text = viewModel.subtitle.uppercased() + ":"
        balanceDetails.text = viewModel.details

        actionControl.isUserInteractionEnabled = false
        tokenBackgroundView.applyDisabledStyle()
    }
}

extension WalletDisplayTokenView: WalletFormBordering {}
