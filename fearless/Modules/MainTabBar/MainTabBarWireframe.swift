import Foundation
import UIKit
import WalletConnectSign

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    func presentPolkaswap(on view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard
            let tabBarController = view?.controller,
            let viewController = LiquidityPoolsOverviewAssembly.configureModule(wallet: wallet)?.view.controller
        else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: viewController)

//        guard
//            let tabBarController = view?.controller,
//            let viewController = PolkaswapAdjustmentAssembly.configureModule(chainAsset: nil, wallet: wallet)?.view.controller
//        else {
//            return
//        }
//
//        let navigationController = FearlessNavigationController(rootViewController: viewController)
        let presentingController = tabBarController.topModalViewController
        presentingController.present(navigationController, animated: true, completion: nil)
    }

    func showNewCrowdloan(on view: MainTabBarViewProtocol?) -> UIViewController? {
        if let view = view {
            return MainTabBarViewFactory.reloadCrowdloanView(
                on: view
            )
        }

        return nil
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

    func replaceStaking(
        on view: MainTabBarViewProtocol?,
        type: AssetSelectionStakingType,
        moduleOutput: StakingMainModuleOutput?
    ) {
        guard let view = view else {
            return
        }

        MainTabBarViewFactory.reloadStakingView(
            on: view,
            stakingType: type,
            moduleOutput: moduleOutput
        )
    }
}
