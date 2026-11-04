import UIKit
import SSFModels

final class ChainAssetListRouter: ChainAssetListRouterInput {
    func showFundingOptions(from view: ControllerBackedProtocol?, title: String, options: [PortfolioFundingOption], locale: Locale) {
        guard let controller = view?.controller, controller.presentedViewController == nil, !options.isEmpty else { return }
        let picker = PortfolioFundingPickerViewController(title: title, options: options, locale: locale)
        let navigation = UINavigationController(rootViewController: picker)
        // On iPad the picker is a card over the wallet; iPhone keeps the full screen.
        navigation.modalPresentationStyle = controller.traitCollection.userInterfaceIdiom == .pad
            ? .formSheet : .fullScreen
        controller.present(navigation, animated: true)
    }

    func showGroupHideConfirmation(from view: ControllerBackedProtocol?, viewModel: SheetAlertPresentableViewModel) {
        guard let controller = view?.controller, controller.presentedViewController == nil else { return }
        controller.present(PortfolioGroupHideViewController(viewModel: viewModel), animated: true)
    }

    func showPurchase(from view: ControllerBackedProtocol?, action: PurchaseAction) {
        guard let controller = view?.controller, controller.presentedViewController == nil,
              let purchase = PurchaseViewFactory.createView(for: action) else { return }
        controller.present(FearlessNavigationController(rootViewController: purchase.controller), animated: true)
    }

    func showAssetNetworks(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let chainAssetView = WalletChainAccountDashboardViewFactory.createNetworksView(
            chainAsset: chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            chainAssetView.controller,
            animated: true
        )
    }

    func showChainAccount(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let chainAssetView = WalletChainAccountDashboardViewFactory.createDetailsView(
            chainAsset: chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            chainAssetView.controller,
            animated: true
        )
    }

    func showSendFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let controller = SendAssembly.configureModule(
            wallet: wallet,
            initialData: .chainAsset(chainAsset)
        )?.view.controller else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }

    func showReceiveFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        let module = ReceiveAndRequestAssetAssembly.configureModule(wallet: wallet, chainAsset: chainAsset)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }

    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        actions: [SheetAlertPresentableAction]
    ) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let title = R.string.localizable.importSourcePickerTitle(preferredLanguages: locale?.rLanguages)
        let alertViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: cancelTitle,
            icon: nil
        )

        present(
            viewModel: alertViewModel,
            from: view
        )
    }

    func showCreate(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let controller = UsernameSetupViewFactory.createViewForOnboarding(
            flow: .chain(model: uniqueChainModel)
        )?.controller else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let importController = AccountImportViewFactory.createViewForOnboarding(
            defaultSource: .mnemonic,
            flow: .chain(model: uniqueChainModel)
        )?.controller else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: importController
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showManageAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        filter: NetworkManagmentFilter?,
        visibilityFilter: ManageAssetsFilter
    ) {
        let module = AssetManagementAssembly.configureModule(networkFilter: filter, wallet: wallet, visibilityFilter: visibilityFilter)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }

    func showIssueNotification(
        from view: ControllerBackedProtocol?,
        issues: [ChainIssue],
        wallet: MetaAccountModel
    ) {
        guard let module = NetworkIssuesNotificationAssembly.configureModule(
            wallet: wallet,
            issues: issues
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showWalletManagment(from view: ControllerBackedProtocol?) {
        guard let module = WalletsManagmentAssembly.configureModule(
            shouldSaveSelected: true,
            moduleOutput: nil
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
