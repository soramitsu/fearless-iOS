import Foundation
import UIKit
import SSFModels

final class ChainAccountWireframe: ChainAccountWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showDetails(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
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

    func presentSendFlow(
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

    func presentCrossChainFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard ReviewedXcmExecutionAuthority.isAvailable else {
            presentCrossChainCapability(
                title: "Cross-chain route unavailable",
                message: ReviewedXcmExecutionAuthority.unavailableReason,
                from: view
            )
            return
        }

        let chains = ChainRegistryFacade.sharedRegistry.availableChains
        let routes = [
            WalletXcmRouteProvider().origins(wallet: wallet, chains: chains),
            LiberlandXcmRouteProvider().origins(wallet: wallet, chains: chains)
        ]
        .flatMap { $0 }
        .filter {
            $0.chainAsset.chain.chainId == chainAsset.chain.chainId &&
                $0.chainAsset.asset.id == chainAsset.asset.id &&
                $0.chainAsset.asset.precision == chainAsset.asset.precision
        }

        guard routes.count == 1, let route = routes.first else {
            presentCrossChainCapability(
                title: "No supported route",
                message: "This exact network and canonical asset are not available through a reviewed Cross-chain provider.",
                from: view
            )
            return
        }
        guard MultiChainFeaturePolicy.current.crossChainMutationsEnabled else {
            presentCrossChainCapability(
                title: "Cross-chain actions paused",
                message: "Reviewed routes remain visible in the Cross-chain tab, but transfers are temporarily disabled by the remote safety switch.",
                from: view
            )
            return
        }
        guard route.canSign else {
            presentCrossChainCapability(
                title: "Route unavailable",
                message: route.unavailableReason ?? "This wallet cannot sign the selected route.",
                from: view
            )
            return
        }
        guard let controller = CrossChainAssembly.configureModule(
            with: chainAsset,
            wallet: wallet,
            reviewedRoute: route.reviewedContext
        )?.view.controller else {
            presentCrossChainCapability(
                title: "No supported route",
                message: "The reviewed route no longer matches the current network registry.",
                from: view
            )
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: controller)

        view?.controller.present(navigationController, animated: true)
    }

    private func presentCrossChainCapability(
        title: String,
        message: String,
        from view: ControllerBackedProtocol?
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view?.controller.present(alert, animated: true)
    }

    func presentReceiveFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let module = ReceiveAndRequestAssetAssembly.configureModule(wallet: wallet, chainAsset: chainAsset)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }

    func presentBuyFlow(
        from view: ControllerBackedProtocol?,
        items: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    ) {
        let buyView = ModalPickerFactory.createPickerForList(
            items,
            delegate: delegate,
            context: nil
        )

        guard let buyView = buyView else {
            return
        }

        view?.controller.navigationController?.present(buyView, animated: true)
    }

    func presentChainActionsFlow(
        from view: ControllerBackedProtocol?,
        items: [ChainAction],
        chain: ChainModel,
        callback: @escaping ModalPickerSelectionCallback
    ) {
        let actionsView = ModalPickerFactory.createPickerForList(
            title: chain.name,
            items,
            callback: callback,
            context: nil
        )

        guard let actionsView = actionsView else {
            return
        }

        view?.controller.navigationController?.present(actionsView, animated: true)
    }

    func presentPurchaseWebView(
        from view: ControllerBackedProtocol?,
        action: PurchaseAction
    ) {
        let webView = PurchaseViewFactory.createView(
            for: action
        )
        if let webViewController = webView?.controller {
            view?.controller.present(webViewController, animated: true, completion: nil)
        }
    }

    func presentNodeSelection(
        from view: ControllerBackedProtocol?,
        chain: ChainModel
    ) {
        guard let controller = NodeSelectionViewFactory.createView(chain: chain)?.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }

    func showExport(
        for address: String,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        performExportPresentation(
            for: address,
            chain: chain,
            options: options,
            locale: locale,
            wallet: wallet,
            from: view
        )
    }

    func showUniqueChainSourceSelection(
        from view: ControllerBackedProtocol?,
        items: [ReplaceChainOption],
        callback: @escaping ModalPickerSelectionCallback
    ) {
        let actionsView = ModalPickerFactory.createPickerForList(
            items,
            callback: callback,
            context: nil
        )

        guard let actionsView = actionsView else {
            return
        }

        view?.controller.navigationController?.present(actionsView, animated: true)
    }

    func showCreate(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let createController = AccountCreateViewFactory.createViewForOnboarding(
            model: UsernameSetupModel(username: uniqueChainModel.meta.name),
            flow: .chain(model: uniqueChainModel)
        )?.controller else {
            return
        }
        createController.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(createController, animated: true)
    }

    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let importController = AccountImportViewFactory.createViewForOnboarding(
            defaultSource: .mnemonic,
            flow: .chain(model: uniqueChainModel)
        )?.controller else {
            return
        }
        importController.hidesBottomBarWhenPushed = true
        let navigationController = FearlessNavigationController(rootViewController: importController)
        view?.controller.navigationController?.present(navigationController, animated: true)
    }

    func showSelectNetwork(
        from view: ChainAccountViewProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    ) {
        guard
            let module = SelectNetworkAssembly.configureModule(
                wallet: wallet,
                selectedChainId: selectedChainId,
                chainModels: chainModels,
                includingAllNetworks: false,
                searchTextsViewModel: nil,
                delegate: delegate
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showPolkaswap(
        from view: ChainAccountViewProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let module = PolkaswapAdjustmentAssembly.configureModule(chainAsset: chainAsset, wallet: wallet) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.navigationController?.present(
            navigationController,
            animated: true
        )
    }

    func presentLockedInfo(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let module = BalanceLocksDetailAssembly.configureModule(chainAsset: chainAsset, wallet: wallet) else {
            return
        }
        view?.controller.present(module.view.controller, animated: true)
    }

    func showClaimCrowdloanRewardsFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let module = ClaimCrowdloanRewardsAssembly.configureModule(wallet: wallet, chainAsset: chainAsset) else {
            return
        }

        view?.controller.navigationController?.present(module.view.controller, animated: true)
    }
}

private extension ChainAccountWireframe {
    func performExportPresentation(
        for address: String,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let actions: [SheetAlertPresentableAction] = options.map { option in
            switch option {
            case .mnemonic:
                let title = R.string.localizable.importMnemonic(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.authorize(
                        animated: true,
                        cancellable: true,
                        from: view
                    ) { [weak self] success in
                        if success {
                            self?.showMnemonicExport(for: address, chain: chain, wallet: wallet, from: view)
                        }
                    }
                }
            case .keystore:
                let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.authorize(
                        animated: true,
                        cancellable: true,
                        from: view
                    ) { [weak self] success in
                        if success {
                            self?.showKeystoreExport(for: address, chain: chain, wallet: wallet, from: view)
                        }
                    }
                }
            case .seed:
                let title = R.string.localizable.importRawSeed(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.authorize(
                        animated: true,
                        cancellable: true,
                        from: view
                    ) { [weak self] success in
                        if success {
                            self?.showSeedExport(for: address, chain: chain, wallet: wallet, from: view)
                        }
                    }
                }
            }
        }

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

    func showMnemonicExport(
        for address: String,
        chain: ChainModel,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let mnemonicView = ExportMnemonicViewFactory.createViewForAddress(
            flow: .single(chain: chain, address: address, wallet: wallet)
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            mnemonicView.controller,
            animated: true
        )
    }

    func showKeystoreExport(
        for address: String,
        chain: ChainModel,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let passwordView = AccountExportPasswordViewFactory.createView(
            flow: .single(chain: chain, address: address, wallet: wallet)
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            passwordView.controller,
            animated: true
        )
    }

    func showSeedExport(for address: String, chain: ChainModel, wallet: MetaAccountModel, from view: ControllerBackedProtocol?) {
        guard let seedView = ExportSeedViewFactory.createViewForAddress(flow: .single(chain: chain, address: address, wallet: wallet)) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            seedView.controller,
            animated: true
        )
    }
}
