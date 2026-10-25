import Foundation

public struct ConvenienceError: Error {
    let error: String

    public init(error: String) {
        self.error = error
    }
}

struct ErrorContent {
    let title: String
    let message: String
}

extension ConvenienceError: LocalizedError {
    public var errorDescription: String? {
        NSLocalizedString(error, comment: "")
    }
}

protocol ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent
}

extension ConvenienceError: ErrorContentConvertible {
    func toErrorContent(for _: Locale?) -> ErrorContent {
        ErrorContent(title: error, message: "")
    }
}

struct ConvenienceContentError: Error {
    let title: String
    let message: String
}

extension ConvenienceContentError: ErrorContentConvertible {
    func toErrorContent(for _: Locale?) -> ErrorContent {
        ErrorContent(title: title, message: message)
    }
}
