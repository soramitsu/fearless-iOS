import Foundation
import SSFModels

final class StakingBalanceWireframe: StakingBalanceWireframeProtocol {
    func showBondMore(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBondMoreFlow
    ) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else { return }
        let navigationController = ImportantFlowViewFactory.createNavigation(from: bondMoreView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showUnbond(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingUnbondSetupFlow
    ) {
        guard let unbondView = StakingUnbondSetupViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unbondView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeem(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemConfirmationFlow
    ) {
        var redeemCompletion: (() -> Void)?
        if case .parachain = flow {
            redeemCompletion = {
                view?.controller.navigationController?.popViewController(animated: true)
            }
        }
        guard let redeemView = StakingRedeemConfirmationViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            redeemCompletion: redeemCompletion
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: redeemView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRebondSetup(from view: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet: MetaAccountModel) {
        let rebondView: ControllerBackedProtocol? = StakingRebondSetupViewFactory.createView(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedAccount: wallet
        )

        guard let controller = rebondView?.controller else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRebondConfirm(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    ) {
        let rebondView: ControllerBackedProtocol? = StakingRebondConfirmationViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow
        )

        guard let controller = rebondView?.controller else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func cancel(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
