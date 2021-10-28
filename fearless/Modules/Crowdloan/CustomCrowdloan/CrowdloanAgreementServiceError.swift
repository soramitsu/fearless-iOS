import Foundation

enum CrowdloanAgreementServiceError: Error, ErrorContentConvertible {
    case networkError
    case internalError
    case moonbeamForbidden

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .networkError:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.commonErrorNetwork(preferredLanguages: locale?.rLanguages)
            )
        case .internalError:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.commonErrorInternal(preferredLanguages: locale?.rLanguages)
            )
        case .moonbeamForbidden:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.moonbeamLocationUnsupportedError(preferredLanguages: locale?.rLanguages)
            )
        }
    }
}
