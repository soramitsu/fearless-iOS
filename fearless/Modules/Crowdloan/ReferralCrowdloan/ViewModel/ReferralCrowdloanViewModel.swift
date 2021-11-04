import Foundation

struct ReferralCrowdloanViewModel {
    let bonusPercentage: String
    let bonusValue: String
    let canApplyDefaultCode: Bool
    let isTermsAgreed: Bool
    let isCodeReceived: Bool
    let customFlow: CustomCrowdloanFlow?
}

extension ReferralCrowdloanViewModel {
    func applyAppBonusButtonTitle(for preferredLanguages: [String]?) -> String? {
        if canApplyDefaultCode {
            return R.string.localizable.applyFearlessWalletBonus(
                preferredLanguages: preferredLanguages
            ).uppercased()
        } else {
            return R.string.localizable.appliedFearlessWalletBonus(
                preferredLanguages: preferredLanguages
            ).uppercased()
        }
    }

    func actionButtonTitle(for preferredLanguages: [String]?) -> String? {
        if isCodeReceived {
            return R.string.localizable.karuraReferralCodeAction(
                preferredLanguages: preferredLanguages
            )
        } else if isTermsAgreed {
            return R.string.localizable.karuraTermsAction(
                preferredLanguages: preferredLanguages
            )
        } else {
            return R.string.localizable.commonApply(
                preferredLanguages: preferredLanguages
            )
        }
    }
}
