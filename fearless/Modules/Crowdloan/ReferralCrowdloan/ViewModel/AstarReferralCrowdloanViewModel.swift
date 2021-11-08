import Foundation

struct AstarReferralCrowdloanViewModel: ReferralCrowdloanViewModelProtocol {
    let bonusPercentage: String
    let myBonusValue: String
    let friendBonusValue: String
    var canApplyDefaultCode: Bool
    let isCodeReceived: Bool
}

extension AstarReferralCrowdloanViewModel {
    func actionButtonTitle(for preferredLanguages: [String]?) -> String? {
        if !isCodeReceived {
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
