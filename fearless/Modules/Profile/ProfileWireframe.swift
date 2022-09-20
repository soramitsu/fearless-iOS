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

    func showAccountSelection(from view: ProfileViewProtocol?) {
        guard let accountManagement = AccountManagementViewFactory.createViewForSettings() else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountManagement.controller,
            animated: true
        )
    }

    func showConnectionSelection(from view: ProfileViewProtocol?) {
        guard let networkManagement = NetworkManagementViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            networkManagement.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(networkManagement.controller, animated: true)
        }
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
