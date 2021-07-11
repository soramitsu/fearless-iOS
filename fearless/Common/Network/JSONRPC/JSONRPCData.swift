import Foundation

struct JSONRPCError: Error, Decodable {
    let message: String
    let code: Int
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

@propertyWrapper
struct IntStringDecoder: Decodable {
    let wrappedValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            wrappedValue = stringValue
        } else {
            let intValue = try container.decode(Int.self)
            wrappedValue = String(intValue)
        }
    }
}

struct JSONRPCSubscriptionUpdate<T: Decodable>: Decodable {
    struct Result: Decodable {
        let result: T
        @IntStringDecoder var subscription: String
    }

    let jsonrpc: String
    let method: String
    let params: Result
}

struct JSONRPCSubscriptionBasicUpdate: Decodable {
    struct Result: Decodable {
        @IntStringDecoder var subscription: String
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
