import Foundation
import SSFModels

final class ChainAssetListRouter: ChainAssetListRouterInput {
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
        filter: NetworkManagmentFilter?
    ) {
        let module = AssetManagementAssembly.configureModule(networkFilter: filter, wallet: wallet)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }
}
