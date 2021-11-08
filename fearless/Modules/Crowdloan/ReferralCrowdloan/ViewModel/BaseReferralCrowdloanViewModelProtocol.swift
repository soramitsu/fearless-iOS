import Foundation

protocol BaseReferralCrowdloanViewModelProtocol {
    var canApplyDefaultCode: Bool { get set }

    func applyAppBonusButtonTitle(for preferredLanguages: [String]?) -> String?
}

extension BaseReferralCrowdloanViewModelProtocol {
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
}
