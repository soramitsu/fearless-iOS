import Foundation

class AstarReferralCrowdloanPresenter: ReferralCrowdloanPresenter {
    private var referRate: Decimal {
        0.01
    }

    override func provideReferralViewModel() {
        let friendBonusValue = crowdloanViewModelFactory.createAdditionalBonusViewModel(
            inputAmount: inputAmount,
            displayInfo: displayInfo,
            bonusRate: bonusService.bonusRate,
            locale: selectedLocale
        )

        let myBonusValue = crowdloanViewModelFactory.createAdditionalBonusViewModel(
            inputAmount: inputAmount,
            displayInfo: displayInfo,
            bonusRate: referRate,
            locale: selectedLocale
        )

        let bonusPercentage = NumberFormatter.percentSingle.string(from: bonusService.bonusRate as NSNumber)

        let viewModel = AstarReferralCrowdloanViewModel(
            bonusPercentage: bonusPercentage ?? "",
            myBonusValue: myBonusValue ?? "",
            friendBonusValue: friendBonusValue ?? "",
            canApplyDefaultCode: currentReferralCode != defaultReferralCode,
            isCodeReceived: currentReferralCode.isEmpty
        )

        view?.didReceiveState(state: .loadedAstarFlow(viewModel))
    }

    override func applyInputCode() {
        if currentReferralCode.isEmpty {
            view?.didReceiveShouldInputCode()
            return
        }

        view?.didStartLoading()

        bonusService.save(referralCode: currentReferralCode) { [weak self] result in
            self?.view?.didStopLoading()
            self?.handleSave(result: result)
        }
    }
}
