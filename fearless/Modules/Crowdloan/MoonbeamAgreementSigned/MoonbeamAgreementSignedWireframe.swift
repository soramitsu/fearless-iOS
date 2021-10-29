import Foundation

final class MoonbeamAgreementSignedWireframe: MoonbeamAgreementSignedWireframeProtocol {
    func presentContributionSetup(
        from view: MoonbeamAgreementSignedViewProtocol?,
        paraId: ParaId
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(for: paraId) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true

        guard var viewControllers = view?.controller.navigationController?.viewControllers else { return }

        _ = viewControllers.popLast()
        viewControllers.append(setupView.controller)

        view?.controller.navigationController?.setViewControllers(viewControllers, animated: true)
    }
}
