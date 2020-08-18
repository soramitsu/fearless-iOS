import Foundation

enum AccountCreationError: Error {
    case unsupportedNetwork
    case invalidDerivationHardSoftPassword
    case invalidDerivationHardPassword
    case invalidDerivationHardSoft
    case invalidDerivationHard
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
        case .invalidDerivationHardSoftPassword:
            title = R.string.localizable
                .commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonInvalidPathWithSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardPassword:
            title = R.string.localizable
                .commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonInvalidPathWithoutSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardSoft:
            title = R.string.localizable
                .commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonInvalidHardSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHard:
            title = R.string.localizable
                .commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonInvalidHardMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
