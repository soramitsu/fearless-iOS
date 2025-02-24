import Foundation
import UIKit
import WalletConnectSign
import SSFModels

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    func showPolkaswap(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let module = SwapContainerAssembly.configureModule(wallet: wallet, chainAsset: chainAsset) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(
            navigationController,
            animated: true
        )
    }
    
    func presentCrossChainFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        
        guard let controller = CrossChainSwapSetupAssembly.configureModule(
            wallet: wallet,
            chainAsset: chainAsset,
            moduleOutput: nil
        )?.view.controller else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: controller)

        view?.controller.present(navigationController, animated: true)
    }
    
    func presentSwapAssetSelection(
        on view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        onSelectHandler: ((ChainAsset?) -> Void)?
    ) {
        guard
            let tabBarController = view?.controller,
            let module = MultichainAssetSelectionAssembly.configureModule(
                 flow: .okxSource,
                 wallet: wallet,
                 selectAssetModuleOutput: nil,
                 selectedChainAsset: nil,
                 filter: nil,
                 onSelectHandler: onSelectHandler
            )
        else {
            return
        }

        let presentingController = tabBarController.topModalViewController
        presentingController.present(module.view.controller, animated: true, completion: nil)
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
