import Foundation

struct DappFunctionInvokeMessage {
    let type: DappBridgeFunctionType
    let invocationId: String
    let args: [Any]
}

enum DappBridgeFunctionType: String, Codable {
    case send
    case connect
    case restoreConnection
    case disconnect
}
