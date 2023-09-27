import Foundation
import JSONRPC
// import WalletConnectSwiftV2

extension JSONRPCError {
    // SignReasonCode
    static let userRejected = JSONRPCError(
        code: 4001,
        message: "User rejected request"
    )

    static let unauthorizedChain = JSONRPCError(
        code: 3005,
        message: "Unauthorized target chain id requested"
    )

    static let unauthorizedMethod = JSONRPCError(
        code: 3001,
        message: "Unauthorized JSON-RPC method"
    )

    static let unsupportedAccounts = JSONRPCError(
        code: 5103,
        message: "Unsupported or empty accounts for namespace"
    )
}

extension JSONRPCError: ErrorContentConvertible {
    func toErrorContent(for _: Locale?) -> ErrorContent {
        ErrorContent(title: "\(code)", message: message)
    }
}
