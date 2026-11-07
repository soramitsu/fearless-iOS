import Foundation
import UIKit
import FearlessWalletConnect

/// What WalletConnect Verify reports about the app behind a proposal or request: whether
/// the website it runs on is the domain it claims, and whether it is a known scam.
enum WalletConnectVerification: Equatable {
    /// The request comes from the domain the app claims.
    case verified
    /// Verify has no record of the domain, so only the app's own claim names the site.
    case unverified
    /// The request comes from `origin`, another domain than the one the app claims.
    case mismatch(origin: String)
    /// Verify lists the domain as a scam. Such proposals and requests are declined.
    case scam

    init(context: VerifyContext?) {
        switch context?.validation {
        case .valid:
            self = .verified
        case .invalid:
            self = .mismatch(origin: context?.origin ?? "")
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

    /// A warning to show next to the request, when the result calls for one: the site is another than the app
    /// claims, or nothing but the app's own claim names it.
    func warning(for locale: Locale) -> String? {
        switch self {
        case .mismatch:
            return R.string.localizable.walletConnectVerifyInvalidWarning(preferredLanguages: locale.rLanguages)
        case .unverified:
            return R.string.localizable.walletConnectVerifyUnknownWarning(preferredLanguages: locale.rLanguages)
        case .verified, .scam:
            return nil
        }
    }

    var color: UIColor? {
        switch self {
        case .verified:
            return R.color.colorGreen()
        case .unverified:
            return R.color.colorOrange()
        case .mismatch:
            return R.color.colorOrange()
        case .scam:
            return R.color.colorRed()
        }
    }

    /// The website to show for the app: where the request really came from when Verify saw another site than the
    /// app claims, otherwise the site the app claims (which Verify confirmed, or could not check).
    func website(claimed url: String) -> String {
        switch self {
        case let .mismatch(origin) where !origin.isEmpty:
            return Self.host(of: origin)
        case .verified, .unverified, .mismatch, .scam:
            return Self.host(of: url)
        }
    }

    /// The host Verify saw the request come from, for messages about it.
    static func host(of origin: String) -> String {
        URL(string: origin)?.host ?? origin
    }
}
