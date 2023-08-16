import Foundation

final class BackupWalletRouter: BackupWalletRouterInput {
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

            view?.controller.navigationController?.pushViewController(
                mnemonicView.controller,
                animated: true
            )
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

            view?.controller.navigationController?.pushViewController(
                passwordView.controller,
                animated: true
            )
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

            view?.controller.navigationController?.pushViewController(
                seedView.controller,
                animated: true
            )
        }
    }

    func showCreatePassword(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        options: [ExportOption],
        from view: ControllerBackedProtocol?,
        moduleOutput: BackupCreatePasswordModuleOutput?
    ) {
        let exportFlow: ExportFlow = .multiple(wallet: wallet, accounts: accounts)
        let createPassportFlow: BackupCreatePasswordFlow = .backupWallet(flow: exportFlow, options: options)
        guard let module = BackupCreatePasswordAssembly
            .configureModule(with: createPassportFlow, moduleOutput: moduleOutput) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            module.view.controller,
            animated: true
        )
    }

    func showWalletDetails(
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        let module = WalletDetailsViewFactory
            .createView(flow: .normal(wallet: wallet))
        view?.controller.navigationController?.pushViewController(module.controller, animated: true)
    }
}
