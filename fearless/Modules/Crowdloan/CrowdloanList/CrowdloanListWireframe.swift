import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    func presentContributionSetup(from view: CrowdloanListViewProtocol?, paraId: ParaId) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(for: paraId) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(setupView.controller, animated: true)
    }

    func selecteChain(
        from view: CrowdloanListViewProtocol?,
        delegate: ChainSelectionDelegate,
        selectedChainId: ChainModel.Id?
    ) {
        guard let selectionView = ChainSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainId: selectedChainId,
            repositoryFilter: NSPredicate.hasCrowloans()
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
