import Foundation

final class CrowdloanContributionSetupWireframe: CrowdloanContributionSetupWireframeProtocol {
    func showConfirmation(
        from view: CrowdloanContributionSetupViewProtocol?,
        paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?,
        customFlow: CustomCrowdloanFlow?,
        ethereumAddress: String?
    ) {
        guard let confirmationView = CrowdloanContributionConfirmViewFactory.createView(
            with: paraId,
            inputAmount: inputAmount,
            bonusService: bonusService,
            customFlow: customFlow,
            ethereumAddress: ethereumAddress
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
        guard let customFlow = displayInfo.flowIfSupported else {
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
        case .bifrost:
            showBifrostCustomFlow(
                from: view,
                for: displayInfo,
                inputAmount: inputAmount,
                delegate: delegate,
                existingService: existingService
            )
        default: break
        }
    }

    private func showKaruraCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let karuraView = ReferralCrowdloanViewFactory.createKaruraView(
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

    private func showBifrostCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let bifrostView = ReferralCrowdloanViewFactory.createBifrostView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            existingService: existingService
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: bifrostView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
