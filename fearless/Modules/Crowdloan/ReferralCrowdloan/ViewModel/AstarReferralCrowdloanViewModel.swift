import Foundation

struct AstarReferralCrowdloanViewModel {
    let bonusPercentage: String
    let myBonusValue: String
    let friendBonusValue: String
    let canApplyDefaultCode: Bool
    let isCodeReceived: Bool
}

extension AstarReferralCrowdloanViewModel {
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
        } else {
            return R.string.localizable.commonApply(
                preferredLanguages: preferredLanguages
            )
        }
    }
}
