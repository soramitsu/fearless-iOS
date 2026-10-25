import Foundation

public enum CloudStorageServiceError: Error {
    case notFound
    case incorectPassword
    case incorectJson
    case notAuthorized
    case readbackMismatch
}

extension CloudStorageServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Not Found"
        case .incorectPassword:
            return "Incorect password"
        case .incorectJson:
            return "Incorect json"
        case .notAuthorized:
            return "Not authorized"
        case .readbackMismatch:
            return "Uploaded backup does not match Drive readback"
        }
    }
}
