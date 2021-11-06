import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    func presentAgreement(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) {
        switch customFlow {
        case .moonbeam:
            let setupView = CrowdloanAgreementViewFactory.createView(
                for: paraId,
                customFlow: customFlow
            )

            guard let setupView = setupView else { return }

            setupView.controller.hidesBottomBarWhenPushed = true
            view?.controller.navigationController?.pushViewController(
                setupView.controller,
                animated: true
            )
        default: break
        }
    }

    func presentContributionSetup(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow?
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(
            for: paraId,
            customFlow: customFlow
        ) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }
}
