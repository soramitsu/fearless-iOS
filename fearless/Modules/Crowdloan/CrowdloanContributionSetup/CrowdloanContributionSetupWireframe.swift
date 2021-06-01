import Foundation

final class CrowdloanContributionSetupWireframe: CrowdloanContributionSetupWireframeProtocol {
    func showConfirmation(from view: CrowdloanContributionSetupViewProtocol?, paraId: ParaId, inputAmount: Decimal) {
        guard let confirmationView = CrowdloanContributionConfirmViewFactory.createView(
            with: paraId,
            inputAmount: inputAmount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }

    func showCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo
    ) {
        guard let customFlow = displayInfo.customFlow else {
            return
        }

        switch customFlow {
        case .karura:
            showKaruraCustomFlow(from: view, for: displayInfo)
        }
    }

    private func showKaruraCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for _: CrowdloanDisplayInfo
    ) {
        guard let karuraView = KaruraCrowdloanViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(karuraView.controller, animated: true)
    }
}
