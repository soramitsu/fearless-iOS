import Foundation

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    func showNewWalletView(on view: MainTabBarViewProtocol?) {
        if let view = view {
            MainTabBarViewFactory.reloadWalletView(on: view)
        }
    }
}
