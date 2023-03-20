import UIKit

enum SoraCardStatus {
    case pending
    case rejected(hasFreeAttempts: Bool)
    case success
    case failure

    var iconImage: UIImage? {
        switch self {
        case .pending:
            return R.image.soraCardStatusPending()
        case .rejected:
            return R.image.soraCardStatusFailure()
        case .success:
            return R.image.soraCardStatusSuccess()
        case .failure:
            return R.image.soraCardStatusFailure()
        }
    }

    func title(with locale: Locale) -> String {
        switch self {
        case .pending:
            return R.string.localizable.soraCardStatusPendingTitle(preferredLanguages: locale.rLanguages)
        case let .rejected(hasFreeAttempts):
            if hasFreeAttempts {
                return R.string.localizable.soraCardStatusRejectedTitle(preferredLanguages: locale.rLanguages)
            } else {
                return R.string.localizable.noFreeKycAttemptsTitle(preferredLanguages: locale.rLanguages)
            }
        case .success:
            return R.string.localizable.soraCardStatusSuccessTitle(preferredLanguages: locale.rLanguages)
        case .failure:
            return R.string.localizable.soraCardStatusFailureTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func description(with locale: Locale) -> String {
        switch self {
        case .pending:
            return R.string.localizable.soraCardStatusPendingText(preferredLanguages: locale.rLanguages)
        case let .rejected(hasFreeAttempts):
            if hasFreeAttempts {
                return R.string.localizable.soraCardStatusRejectedText(preferredLanguages: locale.rLanguages)
            } else {
                return R.string.localizable.noFreeKycAttemptsDescription(preferredLanguages: locale.rLanguages)
            }
        case .success:
            return R.string.localizable.soraCardStatusSuccessText(preferredLanguages: locale.rLanguages)
        case .failure:
            return R.string.localizable.soraCardStatusFailureText(preferredLanguages: locale.rLanguages)
        }
    }

    func buttonTitle(with locale: Locale) -> String {
        switch self {
        case .rejected:
            return R.string.localizable.tryAgainCommon(preferredLanguages: locale.rLanguages)
        default:
            return R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
        }
    }
}
