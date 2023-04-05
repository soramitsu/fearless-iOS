import Foundation

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
        data: CrossChainConfirmationData
    ) {
        guard let module = CrossChainConfirmationAssembly.configureModule(with: data) else {
            return
        }
        view?.controller.present(module.view.controller, animated: true)
    }
}
