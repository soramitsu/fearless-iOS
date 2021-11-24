import Foundation

enum CommonError: Error {
    case undefined
    case network
    case `internal`
}

extension CommonError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .undefined:
            title = R.string.localizable
                .commonUndefinedErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonUndefinedErrorMessage(preferredLanguages: locale?.rLanguages)
        case .network:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.commonErrorNetwork(preferredLanguages: locale?.rLanguages)
            )
        case .internal:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.commonErrorInternal(preferredLanguages: locale?.rLanguages)
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
