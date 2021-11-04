import Foundation
import UIKit

final class CrowdloanAgreementSignedWireframe: CrowdloanAgreementSignedWireframeProtocol {
    func presentContributionSetup(
        from view: CrowdloanAgreementSignedViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(
            for: paraId,
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
