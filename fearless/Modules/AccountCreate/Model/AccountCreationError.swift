import Foundation

enum AccountCreationError: Error {
    case unsupportedNetwork
    case invalidDerivationPath
    case invalidDerivationPathWithoutSoft
}

extension AccountCreationError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .unsupportedNetwork:
            title = R.string.localizable
                .commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonUnsupportedNetworkMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationPath:
            title = R.string.localizable
                .commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonInvalidPathWithSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationPathWithoutSoft:
            title = R.string.localizable
                .commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonInvalidPathWithoutSoftMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
