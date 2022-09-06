import Foundation

final class ChainAssetListRouter: ChainAssetListRouterInput {
    func showChainAccount(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let chainAssetView = WalletChainAccountDashboardViewFactory.createView(
            chainAsset: chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            chainAssetView.controller,
            animated: true
        )
    }

    func showSendFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        selectedMetaAccount: MetaAccountModel,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        let searchView = SearchPeopleViewFactory.createView(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedMetaAccount: selectedMetaAccount,
            transferFinishBlock: transferFinishBlock
        )

        guard let controller = searchView?.controller else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }

    func showReceiveFlow(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        selectedMetaAccount: MetaAccountModel
    ) {
        let receiveView = ReceiveAssetViewFactory.createView(
            account: selectedMetaAccount,
            chain: chainAsset.chain,
            asset: chainAsset.asset
        )

        guard let controller = receiveView?.controller else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }
}
