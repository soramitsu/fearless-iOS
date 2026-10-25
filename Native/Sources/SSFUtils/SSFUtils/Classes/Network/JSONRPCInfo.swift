import Foundation

public struct JSONRPCInfo<P: Codable>: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case jsonrpc
        case method
        case params
    }

    public let identifier: UInt16
    public let jsonrpc: String
    public let method: String
    public let params: P

    public init(identifier: UInt16, jsonrpc: String, method: String, params: P) {
        self.identifier = identifier
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
    }
}
