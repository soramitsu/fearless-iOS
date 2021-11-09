import Foundation

class AcalaReferralCrowdloanPresenter: ReferralCrowdloanPresenter {
    private(set) var isReceiveEmailAgreed: Bool = false

    override func provideReferralViewModel() {
        let bonusValue = crowdloanViewModelFactory.createAdditionalBonusViewModel(
            inputAmount: inputAmount,
            displayInfo: displayInfo,
            bonusRate: bonusService.bonusRate,
            locale: selectedLocale
        )

        let viewModel = AcalaReferralCrowdloanViewModel(
            canApplyDefaultCode: currentReferralCode != defaultReferralCode,
            bonusValue: bonusValue ?? "",
            isTermsAgreed: isTermsAgreed,
            isReceiveEmailAgreed: isReceiveEmailAgreed,
            isCodeReceived: !currentReferralCode.isEmpty
        )

        view?.didReceiveState(state: .loadedAcalaFlow(viewModel))
    }
}
