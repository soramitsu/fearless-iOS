import Foundation

struct ConvenienceError: Error {
    let error: String
}

extension ConvenienceError: LocalizedError {
    public var errorDescription: String? {
        NSLocalizedString(error, comment: "")
    }
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
