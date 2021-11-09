import Foundation

struct AcalaReferralCrowdloanViewModel: ReferralCrowdloanViewModelProtocol {
    var canApplyDefaultCode: Bool
    let bonusValue: String
    let isTermsAgreed: Bool
    let isReceiveEmailAgreed: Bool
    let isCodeReceived: Bool
}

extension AcalaReferralCrowdloanViewModel {
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
