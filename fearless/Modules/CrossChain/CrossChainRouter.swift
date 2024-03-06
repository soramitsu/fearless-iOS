import Foundation
import SSFXCM
import SSFModels

final class CrossChainRouter: CrossChainRouterInput {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        contextTag: Int?,
        delegate: SelectNetworkDelegate?
    ) {
        guard
            let module = SelectNetworkAssembly.configureModule(
                wallet: wallet,
                selectedChainId: selectedChainId,
                chainModels: chainModels,
                includingAllNetworks: false,
                searchTextsViewModel: nil,
                delegate: delegate,
                contextTag: contextTag
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]?,
        selectedAssetId: AssetModel.Id?,
        output: SelectAssetModuleOutput
    ) {
        guard let module = SelectAssetAssembly.configureModule(
            wallet: wallet,
            selectedAssetId: selectedAssetId,
            chainAssets: chainAssets,
            searchTextsViewModel: .searchAssetPlaceholder,
            output: output,
            isFullSize: true
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        data: CrossChainConfirmationData,
        xcmServices: XcmExtrinsicServices
    ) {
        guard let module = CrossChainConfirmationAssembly.configureModule(with: data, xcmServices: xcmServices) else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            module.view.controller,
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

    func showWalletManagment(
        selectedWalletId: MetaAccountId?,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        guard let module = WalletsManagmentAssembly.configureModule(
            viewType: .selectYourWallet(selectedWalletId: selectedWalletId),
            shouldSaveSelected: false,
            moduleOutput: moduleOutput
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
