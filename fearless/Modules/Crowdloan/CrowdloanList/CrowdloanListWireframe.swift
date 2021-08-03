import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    func presentContributionSetup(from view: CrowdloanListViewProtocol?, paraId: ParaId) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(for: paraId) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(setupView.controller, animated: true)
    }
}
