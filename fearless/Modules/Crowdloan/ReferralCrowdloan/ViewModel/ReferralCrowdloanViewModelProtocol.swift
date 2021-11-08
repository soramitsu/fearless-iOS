import Foundation

protocol ReferralCrowdloanViewModelProtocol {
    var canApplyDefaultCode: Bool { get set }

    func applyAppBonusButtonTitle(for preferredLanguages: [String]?) -> String?
}

extension ReferralCrowdloanViewModelProtocol {
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
