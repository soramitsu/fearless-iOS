import Foundation
import SSFModels
import SSFQRService

final class TransferRouter: TransferRouterInput {
    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    ) {
        let matcher = QRInfoMatcher(decoder: QRDecoderDefault())
        guard let module = ScanQRAssembly.configureModule(moduleOutput: moduleOutput, matchers: [matcher]) else {
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

    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        useCase: TransferFlowUseCase,
        sendFlow: SendFlowInitialData,
        scamInfo: ScamInfo?
    ) {
        let module = ConfirmTransferAssembly.configureModule(
            wallet: wallet,
            chainAsset: chainAsset,
            useCase: useCase,
            sendFlow: sendFlow,
            scamInfo: scamInfo
        )

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            controller,
            animated: true
        )
    }
}
