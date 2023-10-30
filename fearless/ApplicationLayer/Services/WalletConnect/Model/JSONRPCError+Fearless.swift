import Foundation
import JSONRPC

extension JSONRPCError {
    // SignReasonCode
    static let userRejected = JSONRPCError(
        code: 4001,
        message: "User rejected request"
    )
}

extension JSONRPCError: ErrorContentConvertible {
    func toErrorContent(for _: Locale?) -> ErrorContent {
        ErrorContent(title: "\(code)", message: message)
    }
}
