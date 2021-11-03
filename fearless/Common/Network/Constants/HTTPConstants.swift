import Foundation

enum HTTPErrorCode: NSInteger {
    case success = 200
    case created = 201
    case accepted = 202
    case noContent = 204
    case badRequest = 400
    case unauthoriezed = 401
    case forbidden = 403
    case notFound = 404
}
