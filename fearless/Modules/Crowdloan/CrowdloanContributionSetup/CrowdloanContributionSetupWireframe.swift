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
}
