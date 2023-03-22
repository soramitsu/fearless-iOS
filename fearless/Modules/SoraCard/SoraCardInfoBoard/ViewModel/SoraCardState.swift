import Foundation

enum SoraCardState {
    case none
    case verification
    case verificationFailed
    case rejected
    case onway
    case active
    case error
    case kycStarted

    func title(for locale: Locale) -> String {
        let preferredLanguages = locale.rLanguages
        switch self {
        case .none:
            return R.string.localizable.soraCardStateNoneTitle(preferredLanguages: preferredLanguages)
        case .verification:
            return R.string.localizable.soraCardStateVerificationTitle(preferredLanguages: preferredLanguages)
        case .verificationFailed:
            return R.string.localizable.soraCardStateVerificationfailedTitle(preferredLanguages: preferredLanguages)
        case .rejected:
            return R.string.localizable.soraCardStateRejectedTitle(preferredLanguages: preferredLanguages)
        case .onway:
            return R.string.localizable.soraCardStateOnwayTitle(preferredLanguages: preferredLanguages)
        case .active:
            // TODO: this is phase#2 - there will be card fiat balance.
            return ""
        case .kycStarted:
            return R.string.localizable.soraCardStateNoneTitle(preferredLanguages: preferredLanguages)
        case .error:
            return R.string.localizable.commonErrorNetwork(preferredLanguages: preferredLanguages)
        }
    }
}
