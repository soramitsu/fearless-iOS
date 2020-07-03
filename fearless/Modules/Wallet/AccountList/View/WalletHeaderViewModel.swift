import Foundation
import CommonWallet

final class WalletHeaderViewModel {
    weak var walletContext: CommonWalletContextProtocol?
}

extension WalletHeaderViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String {
        return R.reuseIdentifier.walletAccountHeaderId.identifier
    }

    var itemHeight: CGFloat {
        return 73.0
    }

    var command: WalletCommandProtocol? { return nil }
}
