import Foundation
import UIKit

final class ProfileWireframe: ProfileWireframeProtocol, AuthorizationPresentable {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showAccountDetails(
        from view: ProfileViewProtocol?,
        metaAccount: MetaAccountModel
    ) {
        let walletDetails = WalletDetailsViewFactory.createView(flow: .normal(wallet: metaAccount))
        let navigationController = FearlessNavigationController(
            rootViewController: walletDetails.controller
        )
        view?.controller.present(navigationController, animated: true)
    }

    func showPincodeChange(from view: ProfileViewProtocol?) {
        authorize(animated: true, cancellable: true, from: view) { [weak self] completed in
            if completed {
                self?.showPinSetup(from: view)
            }
        }
    }

    func showAccountSelection(
        from view: ProfileViewProtocol?,
        moduleOutput: WalletsManagmentModuleOutput
    ) {
        guard
            let module = WalletsManagmentAssembly.configureModule(
                shouldSaveSelected: true,
                moduleOutput: moduleOutput
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showLanguageSelection(from view: ProfileViewProtocol?) {
        guard let languageSelection = LanguageSelectionViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            languageSelection.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(languageSelection.controller, animated: true)
        }
    }

    func showAbout(from view: ProfileViewProtocol?) {
        guard let aboutView = AboutViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            aboutView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(aboutView.controller, animated: true)
        }
    }

    func logout(from _: ProfileViewProtocol?) {
        if let window = SceneWindowFinder.activeWindow() {
            window.rootViewController?.dismiss(animated: true, completion: nil)
            window.rootViewController = nil
            let presenter = RootPresenterFactory.createPresenter(with: window)
            presenter.reload()
        }
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showCheckPincode(
        from view: ProfileViewProtocol?,
        output: CheckPincodeModuleOutput
    ) {
        let checkPincodeViewController = CheckPincodeViewFactory.createView(
            moduleOutput: output
        ).controller
        checkPincodeViewController.modalPresentationStyle = .fullScreen
        view?.controller.present(checkPincodeViewController, animated: true)
    }

    func showSelectCurrency(
        from view: ProfileViewProtocol?,
        with wallet: MetaAccountModel
    ) {
        guard let controller = SelectCurrencyAssembly.configureModule(
            with: wallet,
            isModal: false
        )?.view.controller else { return }
        controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func showPolkaswapDisclaimer(from view: ControllerBackedProtocol?) {
        guard let module = PolkaswapDisclaimerAssembly.configureModule() else {
            return
        }
        view?.controller.present(module.view.controller, animated: true)
    }

    func showWalletConnect(from view: ControllerBackedProtocol?) {
        let module = WalletConnectActiveSessionsAssembly.configureModule()
        guard let controller = module?.view.controller else {
            return
        }

        let navigation = FearlessNavigationController(rootViewController: controller)

        view?.controller.present(navigation, animated: true)
    }

    func showNetworkAssets(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let module = NetworkManagmentAssembly.configureModule(
            wallet: wallet,
            chains: nil,
            contextTag: nil,
            moduleOutput: nil
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showTonConnectCapability(from view: ControllerBackedProtocol?, hasTonAccount: Bool) {
        let message: String
        if hasTonAccount {
            message = NSLocalizedString(
                "settings.tonconnect.unavailable",
                value: "This wallet has a TON account. TonConnect sessions are not supported in this build yet; WalletConnect remains available separately.",
                comment: ""
            )
        } else {
            message = NSLocalizedString(
                "settings.tonconnect.account_required",
                value: "This wallet does not have a TON account. Add one in Wallets & Accounts. TonConnect sessions are not supported in this build yet.",
                comment: ""
            )
        }
        let alert = UIAlertController(
            title: "TonConnect",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: NSLocalizedString("common.ok", value: "OK", comment: ""),
                style: .default
            )
        )
        view?.controller.present(alert, animated: true)
    }

    // MARK: Private

    private func showPinSetup(from view: ProfileViewProtocol?) {
        guard let pinSetup = PinViewFactory.createPinChangeView() else {
            return
        }

        pinSetup.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            pinSetup.controller,
            animated: true
        )
    }
}
