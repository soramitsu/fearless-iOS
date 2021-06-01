import Foundation

final class CrowdloanContributionSetupWireframe: CrowdloanContributionSetupWireframeProtocol {
    func showConfirmation(
        from view: CrowdloanContributionSetupViewProtocol?,
        paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?
    ) {
        guard let confirmationView = CrowdloanContributionConfirmViewFactory.createView(
            with: paraId,
            inputAmount: inputAmount,
            bonusService: bonusService
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }

    func showAdditionalBonus(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let customFlow = displayInfo.customFlow else {
            return
        }

        switch customFlow {
        case .karura:
            showKaruraCustomFlow(
                from: view,
                for: displayInfo,
                inputAmount: inputAmount,
                delegate: delegate,
                existingService: existingService
            )
        }
    }

    private func showKaruraCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let karuraView = KaruraCrowdloanViewFactory.createView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            existingService: existingService
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: karuraView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
