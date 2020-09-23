import Foundation
import IrohaCrypto

enum ModifyConnectionError: Error {
    case alreadyExists
    case invalidConnection
    case unsupportedChain(_ supported: [SNAddressType])
}

extension ModifyConnectionError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let message: String

        switch self {
        case .alreadyExists:
            message = R.string.localizable
                .connectionAddAlreadyExistsError(preferredLanguages: locale?.rLanguages)
        case .invalidConnection:
            message = R.string.localizable
                .connectionAddInvalidError(preferredLanguages: locale?.rLanguages)
        case .unsupportedChain(let supported):
            let supported: String = supported
                .map { $0.titleForLocale(locale ?? Locale.current) }
                .joined(separator: " ,")

            message = R.string.localizable.connectionAddUnsupportedError(supported,
                                                                         preferredLanguages: locale?.rLanguages)
        }

        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)

        return ErrorContent(title: title, message: message)
    }
}
