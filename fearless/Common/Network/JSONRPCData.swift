import Foundation

struct JSONRPCData: Decodable {
    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case result
        case identifier = "id"
    }

    let jsonrpc: String
    let result: String?
    let identifier: Int64
}
