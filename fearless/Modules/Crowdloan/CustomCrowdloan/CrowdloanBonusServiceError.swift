import Foundation

enum CrowdloanBonusServiceError: Error, ErrorContentConvertible {
    case invalidReferral
    case internalError
    case veficationFailed

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .invalidReferral:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.crowdloanReferralCodeInvalid(preferredLanguages: locale?.rLanguages)
            )
        case .internalError:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.crowdloanReferralCodeInternal(preferredLanguages: locale?.rLanguages)
            )
        case .veficationFailed:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.crowdloanBonusVerificationError(preferredLanguages: locale?.rLanguages)
            )
        }
    }
}
