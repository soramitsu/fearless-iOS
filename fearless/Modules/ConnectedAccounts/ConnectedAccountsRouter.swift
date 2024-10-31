import Foundation
import SSFModels

final class ConnectedAccountsRouter: ConnectedAccountsRouterInput {
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
