import Foundation
import UIKit

final class CrowdloanAgreementSignedWireframe: CrowdloanAgreementSignedWireframeProtocol {
    let state: CrowdloanSharedState

    init(state: CrowdloanSharedState) {
        self.state = state
    }

    func presentContributionSetup(
        from view: CrowdloanAgreementSignedViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(
            for: paraId,
            state: state,
            customFlow: customFlow
        ) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true

        guard var viewControllers = view?.controller.navigationController?.viewControllers else { return }

        viewControllers = Array(viewControllers.prefix(1))
        viewControllers.append(setupView.controller)

        view?.controller.navigationController?.setViewControllers(viewControllers, animated: true)
    }
}
