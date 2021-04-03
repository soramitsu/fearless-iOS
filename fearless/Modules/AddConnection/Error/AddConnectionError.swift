import Foundation
import IrohaCrypto

enum AddConnectionError: Error {
    case alreadyExists
    case invalidConnection
    case unsupportedChain(_ supported: [SNAddressType])
}

extension AddConnectionError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let message: String

        switch self {
        case .alreadyExists:
            message = R.string.localizable
                .connectionAddAlreadyExistsError(preferredLanguages: locale?.rLanguages)
        case .invalidConnection:
            message = R.string.localizable
                .connectionAddInvalidError(preferredLanguages: locale?.rLanguages)
        case let .unsupportedChain(supported):
            let supported: String = supported
                .map { $0.titleForLocale(locale ?? Locale.current) }
                .joined(separator: ", ")

            message = R.string.localizable.connectionAddUnsupportedError(
                supported,
                preferredLanguages: locale?.rLanguages
            )
        }

        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)

        return ErrorContent(title: title, message: message)
    }
}
