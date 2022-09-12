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
        wallet: MetaAccountModel,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        let searchView = SearchPeopleViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
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
        wallet: MetaAccountModel
    ) {
        let receiveView = ReceiveAssetViewFactory.createView(
            account: wallet,
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
