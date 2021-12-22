import Foundation

enum AccountCreateError: Error {
    case invalidMnemonicSize
    case invalidMnemonicFormat
    case invalidSeed
    case invalidKeystore
    case unsupportedNetwork
    case duplicated
}

extension AccountCreateError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        var title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let message: String

        switch self {
        case .invalidMnemonicSize:
            message = R.string.localizable
                .accessRestoreWordsErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalidMnemonicFormat:
            title = R.string.localizable
                .importMnemonicInvalidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .mnemonicErrorTryAnotherOne(preferredLanguages: locale?.rLanguages)
        case .invalidSeed:
            title = R.string.localizable
                .importSeedInvalidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .importSeedInvalidMessage(preferredLanguages: locale?.rLanguages)
        case .invalidKeystore:
            title = R.string.localizable
                .importJsonInvalidFormatTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .importJsonInvalidFormatMessage(preferredLanguages: locale?.rLanguages)
        case .unsupportedNetwork:
            message = R.string.localizable
                .commonUnsupportedNetworkMessage(preferredLanguages: locale?.rLanguages)
        case .duplicated:
            title = R.string.localizable
                .importAccountExistsTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accountErrorTryAnotherOne(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
