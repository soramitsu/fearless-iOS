import Foundation

struct ReferralCrowdloanViewModel: ReferralCrowdloanViewModelProtocol {
    let bonusPercentage: String
    let bonusValue: String
    var canApplyDefaultCode: Bool
    let isTermsAgreed: Bool
    let isCodeReceived: Bool
    let customFlow: CustomCrowdloanFlow?
}

extension ReferralCrowdloanViewModel {
    func actionButtonTitle(for preferredLanguages: [String]?) -> String? {
        if !isCodeReceived {
            return R.string.localizable.karuraReferralCodeAction(
                preferredLanguages: preferredLanguages
            )
        } else if !isTermsAgreed {
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
