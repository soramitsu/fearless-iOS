import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    func presentMoonbeamAgreement(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId,
        crowdloanTitle: String,
        customFlow: CustomCrowdloanFlow
    ) {
        let setupView = CrowdloanAgreementViewFactory.createView(
            for: paraId,
            crowdloanName: crowdloanTitle,
            customFlow: customFlow
        )

        guard let setupView = setupView else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }

    func presentContributionSetup(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(for: paraId) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }
}
