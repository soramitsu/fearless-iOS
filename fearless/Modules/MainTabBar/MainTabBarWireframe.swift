import Foundation
import UIKit
import WalletConnectSign
import SoraFoundation

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    func reloadWalletDependentViews(on view: MainTabBarViewProtocol?, wallet: MetaAccountModel) {
        guard let view else {
            return
        }

        MainTabBarViewFactory.reloadWalletDependentViews(on: view, wallet: wallet)
    }

    func reloadPolkaswapViewIfUnavailable(
        on view: MainTabBarViewProtocol?,
        wallet: MetaAccountModel
    ) {
        guard
            let view,
            view.isPolkaswapUnavailable,
            let controller = MainTabBarViewFactory.createAvailablePolkaswapController(wallet: wallet)
        else {
            return
        }

        view.didReplaceView(for: controller, for: MainTabBarDestination.polkaswap.rawValue)
    }

    func presentAccountImport(on view: MainTabBarViewProtocol?) {
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let importController = AccountImportViewFactory
            .createViewForAdding(defaultSource: .mnemonic)?.controller
        else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: importController)

        let presentingController = tabBarController.topModalViewController
        presentingController.present(navigationController, animated: true, completion: nil)
    }

    // MARK: Private

    private func canPresentImport(on view: UIViewController) -> Bool {
        if isAuthorizing || isAlreadyImporting(on: view) {
            return false
        }

        return true
    }

    private func isAlreadyImporting(on view: UIViewController) -> Bool {
        let topViewController = view.topModalViewController
        let topNavigationController: UINavigationController?

        if let navigationController = topViewController as? UINavigationController {
            topNavigationController = navigationController
        } else if let tabBarController = topViewController as? UITabBarController {
            topNavigationController = tabBarController.selectedViewController as? UINavigationController
        } else {
            topNavigationController = nil
        }

        return topNavigationController?.viewControllers.contains {
            if ($0 as? OnboardingMainViewProtocol) != nil || ($0 as? AccountImportViewProtocol) != nil {
                return true
            } else {
                return false
            }
        } ?? false
    }
}
