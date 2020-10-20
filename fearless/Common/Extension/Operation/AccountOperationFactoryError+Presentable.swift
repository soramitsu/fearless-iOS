import Foundation

extension AccountOperationFactoryError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .decryption:
            title = R.string.localizable
                .accountImportKeystoreDecryptionErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accountImportKeystoreDecryptionErrorMessage(preferredLanguages: locale?.rLanguages)
        default:
            title = R.string.localizable
                .commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonUndefinedErrorMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
