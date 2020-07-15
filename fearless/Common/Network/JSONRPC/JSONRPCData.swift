import Foundation

struct JSONRPCError: Error, Decodable {
    let message: String
    let code: Int
}

struct JSONRPCData: Decodable {
    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case result
        case error
        case identifier = "id"
    }

    let jsonrpc: String
    let result: String?
    let error: JSONRPCError?
    let identifier: UInt16
}
