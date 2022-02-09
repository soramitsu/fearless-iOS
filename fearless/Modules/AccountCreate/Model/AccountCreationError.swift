import Foundation

enum AccountCreationError: Error {
    case unsupportedNetwork
    case invalidDerivationHardSoftNumericPassword
    case invalidDerivationHardSoftPassword
    case invalidDerivationHardPassword
    case invalidDerivationHardSoftNumeric
    case invalidDerivationHardSoft
    case invalidDerivationHard
}

extension AccountCreationError: ErrorContentConvertible {
    private func getTitle(for locale: Locale?) -> String {
        switch self {
        case .unsupportedNetwork:
            return R.string.localizable
                .commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        default:
            return R.string.localizable
                .commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
        }
    }

    private func getMessage(for locale: Locale?) -> String {
        switch self {
        case .unsupportedNetwork:
            return R.string.localizable
                .commonUnsupportedNetworkMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardSoftNumericPassword:
            return R.string.localizable
                .commonInvalidHardSoftNumericPasswordMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardSoftPassword:
            return R.string.localizable
                .commonInvalidPathWithSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardPassword:
            return R.string.localizable
                .commonInvalidPathWithoutSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardSoftNumeric:
            return R.string.localizable
                .commonInvalidHardSoftNumericMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardSoft:
            return R.string.localizable
                .commonInvalidHardSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHard:
            return R.string.localizable
                .commonInvalidHardMessage(preferredLanguages: locale?.rLanguages)
        }
    }

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = getTitle(for: locale)
        let message = getMessage(for: locale)

        return ErrorContent(title: title, message: message)
    }
}
