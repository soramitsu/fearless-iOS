import Foundation
import CommonWallet
import SoraUI

final class WalletDisplayReceiverView: WalletBaseReceiverView {}

extension WalletDisplayReceiverView {
    func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.viewModel = viewModel as? WalletAccountViewModel

        iconView.image = viewModel.icon
        titleLabel.text = viewModel.text
    }
}

extension WalletDisplayReceiverView: WalletFormBordering {}
