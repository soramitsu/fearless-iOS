import Foundation

enum AccountExportPasswordError: Error {
    case passwordMismatch
}

extension AccountExportPasswordError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let message: String

        switch self {
        case .passwordMismatch:
            message = "Password mistmatch"
        }

        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        return ErrorContent(title: title, message: message)
    }
}
