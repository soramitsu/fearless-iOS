import Foundation
import UIKit
import SSFModels

final class ChainAccountWireframe: ChainAccountWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
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
        guard let controller = CrossChainAssembly.configureModule(
            with: chainAsset,
            wallet: wallet
        )?.view.controller else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: controller)

        view?.controller.present(navigationController, animated: true)
    }

    func presentReceiveFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        let receiveView = ReceiveAssetViewFactory.createView(
            account: wallet,
            chain: chain,
            asset: asset
        )

        guard let controller = receiveView?.controller else {
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
        guard let module = PolkaswapAdjustmentAssembly.configureModule(swapChainAsset: chainAsset, wallet: wallet) else {
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
        balanceContext: BalanceContext,
        info: AssetBalanceDisplayInfo,
        currency: Currency
    ) {
        let balanceLocksController = ModalInfoFactory.createFromBalanceContext(
            balanceContext,
            amountFormatter: AssetBalanceFormatterFactory().createDisplayFormatter(for: info, usageCase: .detailsCrypto),
            precision: info.assetPrecision,
            currency: currency
        )
        view?.controller.present(balanceLocksController, animated: true)
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
