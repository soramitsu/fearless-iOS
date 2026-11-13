import Foundation

/// A JSON-RPC 2.0 error, as a dApp receives it for a refused or failed request.
public struct JSONRPCError: Error, Hashable, Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?

    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public static let parseError = JSONRPCError(code: -32700, message: "Parse error")
    public static let invalidRequest = JSONRPCError(code: -32600, message: "Invalid Request")
    public static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    public static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    public static let internalError = JSONRPCError(code: -32603, message: "Internal error")

    var json: JSONValue {
        var object: [String: JSONValue] = ["code": .int(code), "message": .string(message)]
        if let data {
            object["data"] = data.value
        }
        return .object(object)
    }

    init?(json: JSONValue) {
        guard let code = json["code"]?.int64Value, let message = json["message"]?.stringValue else {
            return nil
        }
        self.code = Int(truncatingIfNeeded: code)
        self.message = message
        data = json["data"].map(AnyCodable.init(json:))
    }
}

/// The wallet's answer to a request: a result or an error.
public enum RPCResult: Hashable, Sendable {
    case response(AnyCodable)
    case error(JSONRPCError)
}

/// A JSON-RPC message as it travels inside an envelope or to the relay.
enum RPCMessage: Equatable {
    case request(id: Int64, method: String, params: JSONValue)
    case response(id: Int64, result: RPCResult)

    var id: Int64 {
        switch self {
        case let .request(id, _, _), let .response(id, _):
            return id
        }
    }

    init?(json: JSONValue) {
        guard let object = json.objectValue, let id = object["id"]?.int64Value else {
            return nil
        }

        if let method = object["method"]?.stringValue {
            self = .request(id: id, method: method, params: object["params"] ?? .null)
            return
        }

        if let error = object["error"] {
            guard let rpcError = JSONRPCError(json: error) else {
                return nil
            }
            self = .response(id: id, result: .error(rpcError))
            return
        }

        if let result = object["result"] {
            self = .response(id: id, result: .response(AnyCodable(json: result)))
            return
        }

        return nil
    }

    var json: JSONValue {
        switch self {
        case let .request(id, method, params):
            return .object([
                "id": .int(id),
                "jsonrpc": .string("2.0"),
                "method": .string(method),
                "params": params
            ])
        case let .response(id, .response(result)):
            return .object([
                "id": .int(id),
                "jsonrpc": .string("2.0"),
                "result": result.value
            ])
        case let .response(id, .error(error)):
            return .object([
                "id": .int(id),
                "jsonrpc": .string("2.0"),
                "error": error.json
            ])
        }
    }

    var text: String {
        JSONSerializer.string(from: json)
    }
}

/// Request ids in the form WalletConnect peers use: the time in milliseconds times 1000 plus three random digits.
/// Ids from one generator only increase, so two in the same millisecond still differ.
final class RPCIdentifierGenerator {
    private let lock = NSLock()
    private var last: Int64 = 0

    func next(now: Date) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        let milliseconds = Int64((now.timeIntervalSince1970 * 1000).rounded(.down))
        let candidate = milliseconds * 1000 + Int64.random(in: 0 ..< 1000)
        last = candidate > last ? candidate : last + 1
        return last
    }
}
