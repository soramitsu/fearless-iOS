import SSFModels
import UIKit

/// Leaves the Send flow and opens Receive for the same network: the next step when
/// sending is paused or unavailable there (design 11.8, no dead ends).
protocol SendUnavailableReceivePresenting {
    func presentReceive(
        leavingSendFlowFrom view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

extension SendUnavailableReceivePresenting {
    func presentReceive(
        leavingSendFlowFrom view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        let flowController = view?.controller.navigationController ?? view?.controller
        let presenter = flowController?.presentingViewController

        flowController?.dismiss(animated: true) {
            guard
                let presenter,
                let module = ReceiveAndRequestAssetAssembly.configureModule(wallet: wallet, chainAsset: chainAsset)
            else {
                return
            }

            presenter.present(module.view.controller, animated: true)
        }
    }
}

final class SendRouter: SendRouterInput {
    func presentFormWarning(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        guard let controller = view?.controller else { return }
        let sheet = SheetAletViewController(
            viewModel: viewModel, externalDismissalCompletion: viewModel.dismissCompletion
        )
        sheet.modalPresentationStyle = .custom
        sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        controller.present(sheet, animated: true)
    }

    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        scamInfo: ScamInfo?,
        feeViewModel: BalanceViewModelProtocol?,
        selection: SelectedWalletAuthority.Lease?
    ) {
        guard selection?.isCurrent ?? true, let controller = WalletSendConfirmViewFactory.createView(
            wallet: wallet,
            chainAsset: chainAsset,
            call: call,
            scamInfo: scamInfo,
            feeViewModel: feeViewModel,
            selection: selection
        )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            controller,
            animated: true
        )
    }

    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    ) {
        guard let module = ScanQRAssembly.configureModule(moduleOutput: moduleOutput) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true, completion: nil)
    }

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    ) {
        guard let module = ContactsAssembly.configureModule(
            wallet: wallet,
            source: .token(chainAsset: chainAsset),
            moduleOutput: moduleOutput
        ) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)
        view?.controller.present(navigationController, animated: true)
    }

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
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

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        output: SelectAssetModuleOutput
    ) {
        guard
            let module = SelectAssetAssembly.configureModule(
                wallet: wallet,
                selectedAssetId: selectedAssetId,
                chainAssets: chainAssets,
                searchTextsViewModel: .searchAssetPlaceholder,
                output: output
            )
        else {
            return
        }
        view?.controller.present(module.view.controller, animated: true)
    }

    func showManageAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    ) {
        let module = AssetManagementAssembly.configureModule(networkFilter: nil, wallet: wallet)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }
}
