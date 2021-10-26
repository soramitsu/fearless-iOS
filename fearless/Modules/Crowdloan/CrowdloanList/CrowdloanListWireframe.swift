import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    func presentMoonbeamAgreement(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId,
        crowdloanTitle: String
    ) {
        let setupView = CrowdloanAgreementViewFactory.createMoonbeamView(
            for: paraId,
            crowdloanName: crowdloanTitle
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
