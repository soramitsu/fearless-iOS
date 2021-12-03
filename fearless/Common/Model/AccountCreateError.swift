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
                .accessRestorePhraseErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accessRestorePhraseErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalidSeed:
            title = R.string.localizable
                .accountImportInvalidSeedTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accountImportInvalidSeedMessage(preferredLanguages: locale?.rLanguages)
        case .invalidKeystore:
            title = R.string.localizable
                .accountImportInvalidKeystoreTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accountImportInvalidKeystoreMessage(preferredLanguages: locale?.rLanguages)
        case .unsupportedNetwork:
            message = R.string.localizable
                .commonUnsupportedNetworkMessage(preferredLanguages: locale?.rLanguages)
        case .duplicated:
            title = R.string.localizable
                .accountAddAlreadyExistsTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accountAddAlreadyExistsMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
