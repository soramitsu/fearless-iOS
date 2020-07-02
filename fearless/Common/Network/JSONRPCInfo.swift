import Foundation

struct JSONRPCInfo: Encodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case jsonrpc
        case method
        case params
    }

    let identifier: Int64
    let jsonrpc: String
    let method: String
    let params: [String]
}
