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
        request: MetaAccountImportMnemonicRequest,
        from view: ControllerBackedProtocol?,
        moduleOutput: BackupCreatePasswordModuleOutput?
    ) {
        guard let module = BackupCreatePasswordAssembly
            .configureModule(with: .backupWallet(wallet: wallet, request: request), moduleOutput: moduleOutput) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            module.view.controller,
            animated: true
        )
    }
}
