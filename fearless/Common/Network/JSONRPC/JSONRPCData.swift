import Foundation

struct JSONRPCError: Error, Decodable {
    enum CodingKeys: String, CodingKey {
        case message
        case code
        case data
    }

    let message: String
    let code: Int
    let data: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        message = try container.decode(String.self, forKey: .message)
        code = try container.decode(Int.self, forKey: .code)
        data = try? container.decode(String.self, forKey: .data)
    }
}

struct JSONRPCData<T: Decodable>: Decodable {
    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case result
        case error
        case identifier = "id"
    }

    let jsonrpc: String
    let result: T
    let error: JSONRPCError?
    let identifier: UInt16
}

struct JSONRPCSubscriptionUpdate<T: Decodable>: Decodable {
    struct Result: Decodable {
        let result: T
        let subscription: String
    }

    let jsonrpc: String
    let method: String
    let params: Result
}

struct JSONRPCSubscriptionBasicUpdate: Decodable {
    struct Result: Decodable {
        let subscription: String
    }

    let jsonrpc: String
    let method: String
    let params: Result
}

struct JSONRPCBasicData: Decodable {
    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case error
        case identifier = "id"
    }

    let jsonrpc: String
    let error: JSONRPCError?
    let identifier: UInt16?
}
