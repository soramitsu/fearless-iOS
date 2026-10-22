import Foundation
import UIKit
import FearlessWalletConnect

/// What WalletConnect Verify reports about the app behind a proposal or request: whether
/// the website it runs on is the domain it claims, and whether it is a known scam.
enum WalletConnectVerification: Equatable {
    /// The request comes from the domain the app claims.
    case verified
    /// Verify has no record of the domain.
    case unverified
    /// The request comes from another domain than the one the app claims.
    case mismatch
    /// Verify lists the domain as a scam. Such proposals and requests are declined.
    case scam

    init(context: VerifyContext?) {
        switch context?.validation {
        case .valid:
            self = .verified
        case .invalid:
            self = .mismatch
        case .scam:
            self = .scam
        case .unknown, .none:
            self = .unverified
        }
    }

    func title(for locale: Locale) -> String {
        let languages = locale.rLanguages
        switch self {
        case .verified:
            return R.string.localizable.walletConnectVerifyValid(preferredLanguages: languages)
        case .unverified:
            return R.string.localizable.walletConnectVerifyUnknown(preferredLanguages: languages)
        case .mismatch:
            return R.string.localizable.walletConnectVerifyInvalid(preferredLanguages: languages)
        case .scam:
            return R.string.localizable.walletConnectVerifyScam(preferredLanguages: languages)
        }
    }

    /// A warning to show next to the request, when the result calls for one.
    func warning(for locale: Locale) -> String? {
        switch self {
        case .mismatch:
            return R.string.localizable.walletConnectVerifyInvalidWarning(preferredLanguages: locale.rLanguages)
        case .verified, .unverified, .scam:
            return nil
        }
    }

    var color: UIColor? {
        switch self {
        case .verified:
            return R.color.colorGreen()
        case .unverified:
            return R.color.colorStrokeGray()
        case .mismatch:
            return R.color.colorOrange()
        case .scam:
            return R.color.colorRed()
        }
    }

    /// The host Verify saw the request come from, for messages about it.
    static func host(of origin: String) -> String {
        URL(string: origin)?.host ?? origin
    }
}
