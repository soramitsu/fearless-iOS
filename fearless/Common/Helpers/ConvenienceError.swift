import Foundation

struct ConvenienceError: Error {
    let error: String
}

extension ConvenienceError: LocalizedError {
    public var errorDescription: String? {
        NSLocalizedString(error, comment: "")
    }
}
