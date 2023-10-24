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
        if let window = UIApplication.shared.windows.first {
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
