import Foundation
import SSFModels

final class SendRouter: SendRouterInput {
    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        scamInfo: ScamInfo?,
        remark: Data?
    ) {
        guard let controller = WalletSendConfirmViewFactory.createView(
            wallet: wallet,
            chainAsset: chainAsset,
            receiverAddress: receiverAddress,
            amount: amount,
            tip: tip,
            scamInfo: scamInfo,
            remark: remark
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
            chainAsset: chainAsset,
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
}
