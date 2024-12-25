import Foundation
import SSFModels

final class ConnectedAccountsRouter: ConnectedAccountsRouterInput {
    func showUniqueChainSourceSelection(
        from view: (any ControllerBackedProtocol)?,
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

    func showCreate(
        wallet: SSFModels.MetaAccountModel,
        chains: [SSFModels.ChainModel],
        from view: (any ControllerBackedProtocol)?
    ) {
        guard let createController = AccountCreateViewFactory.createViewForOnboarding(
            ecosystem: .regular,
            model: UsernameSetupModel(username: wallet.name),
            flow: .ethereum(wallet: wallet, chains: chains)
        )?.controller else {
            return
        }
        createController.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(createController, animated: true)
    }

    func showImport(
        wallet: SSFModels.MetaAccountModel,
        chains: [SSFModels.ChainModel],
        defaultSource: AccountImportSource,
        from view: (any ControllerBackedProtocol)?
    ) {
        guard let importController = AccountImportViewFactory.createViewForOnboarding(
            defaultSource: defaultSource,
            flow: .ethereum(wallet: wallet, chains: chains)
        )?.controller else {
            return
        }
        importController.hidesBottomBarWhenPushed = true
        let navigationController = FearlessNavigationController(rootViewController: importController)
        view?.controller.navigationController?.present(navigationController, animated: true)
    }

    func showAccountDetails(
        from view: ControllerBackedProtocol?,
        metaAccount: MetaAccountModel
    ) {
        guard
            let walletOptionsController = WalletOptionAssembly.configureModule(
                with: metaAccount,
                delegate: nil
            )?.view.controller
        else {
            return
        }

        view?.controller.present(walletOptionsController, animated: true)
    }

    func showOptions(
        from view: ControllerBackedProtocol?,
        ecosystem: Ecosystem,
        wallet: MetaAccountModel,
        chains: [ChainModel],
        moduleOutput: EcosystemOptionsModuleOutput?
    ) {
        guard let module = EcosystemOptionsAssembly.configureModule(
            ecosystem: ecosystem,
            wallet: wallet,
            chains: chains,
            moduleOutput: moduleOutput
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showWalletDetails(
        view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chains: [ChainModel]?
    ) {
        let module = WalletDetailsViewFactory.createView(flow: .normal(wallet: wallet), chains: chains)

        view?.controller.navigationController?.pushViewController(module.controller, animated: true)
    }

    func showMnemonicExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    ) {
        authorize(
            animated: true,
            cancellable: true,
            from: view
        ) { isAuthorized in
            guard
                isAuthorized,
                let mnemonicView = ExportMnemonicViewFactory.createViewForAddress(
                    flow: flow
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(mnemonicView.controller, animated: true)
        }
    }

    func showKeystoreExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    ) {
        authorize(
            animated: true,
            cancellable: true,
            from: view
        ) { isAuthorized in
            guard
                isAuthorized,
                let passwordView = AccountExportPasswordViewFactory.createView(
                    flow: flow
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(passwordView.controller, animated: true)
        }
    }

    func showSeedExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    ) {
        authorize(
            animated: true,
            cancellable: true,
            from: view
        ) { isAuthorized in
            guard
                isAuthorized,
                let seedView = ExportSeedViewFactory.createViewForAddress(flow: flow) else {
                return
            }

            view?.controller.navigationController?.pushViewController(seedView.controller, animated: true)
        }
    }
}
