import Foundation
import CommonWallet

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    var walletContext: CommonWalletContextProtocol

    init(walletContext: CommonWalletContextProtocol) {
        self.walletContext = walletContext
    }

    func showNewWalletView(on view: MainTabBarViewProtocol?) {
        if let view = view {
            MainTabBarViewFactory.reloadWalletView(on: view)
        }
    }

    func reloadWalletContent() {
        try? walletContext.prepareAccountUpdateCommand().execute()
    }
}
