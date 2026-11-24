import Foundation
import WalletCore

/// One reader multiplexes calls and subscriptions on the connection.
actor RPCSocket {
    typealias Stream = AsyncThrowingStream<Any, Error>
    struct Subscription {
        let events: Stream
        let cancel: @Sendable () async -> Void
    }

    enum Token: Hashable, Sendable {
        case string(String), number(Int)

        init?(_ value: Any?) {
            if let text = value as? String {
                self = .string(text)
            } else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                      let integer = value as? Int {
                self = .number(integer)
            } else {
                return nil
            }
        }

        var value: Any {
            switch self {
            case let .string(text): return text
            case let .number(integer): return integer
            }
        }
    }

    private struct Pending {
        let reply: CheckedContinuation<Any, Error>
        let timer: Task<Void, Never>
        let stream: Stream.Continuation?
    }

    private let session: URLSession
    let url: URL
    private var socket: URLSessionWebSocketTask?
    private var sequence = 0
    private var pending: [Int: Pending] = [:]
    private var streams: [Token: Stream.Continuation] = [:]
    private var idle: Task<Void, Never>?

    init(url: URL, session: URLSession) {
        self.url = url; self.session = session
    }

    func request(
        _ method: String,
        _ params: [Any],
        timeout: TimeInterval,
        stream: Stream.Continuation? = nil
    ) async throws -> Any {
        idle?.cancel()
        let ws: URLSessionWebSocketTask
        if let socket {
            ws = socket
        } else {
            ws = session.webSocketTask(with: url)
            ws.maximumMessageSize = 16 * 1024 * 1024
            socket = ws
            ws.resume()
            Task { await read(ws) }
        }
        sequence += 1
        let id = sequence
        let data = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ])
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timer = Task {
                    try? await Task.sleep(for: .seconds(timeout))
                    if !Task.isCancelled {
                        fail(id, WalletError.network("RPC timed out."))
                    }
                }
                pending[id] = Pending(reply: continuation, timer: timer, stream: stream)
                Task {
                    do { try await ws.send(.string(String(decoding: data, as: UTF8.self))) }
                    catch { fail(id, WalletError.network("Could not send the RPC request.")) }
                }
            }
        } onCancel: { Task { await self.fail(id, CancellationError()) } }
    }

    private func fail(_ id: Int, _ error: Error) {
        guard let call = pending.removeValue(forKey: id) else { return }
        call.timer.cancel()
        call.reply.resume(throwing: error)
        scheduleIdleClose()
    }

    private func read(_ ws: URLSessionWebSocketTask) async {
        do {
            while ws === socket {
                let data: Data
                switch try await ws.receive() {
                case let .string(text): data = Data(text.utf8)
                case let .data(bytes): data = bytes
                @unknown default: throw WalletError.network("Invalid WebSocket frame.")
                }
                guard let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if let id = message["id"] as? Int, let call = pending.removeValue(forKey: id) {
                    call.timer.cancel()
                    if let result = message["result"] {
                        if let stream = call.stream, let token = Token(result) {
                            streams[token] = stream
                        }
                        call.reply.resume(returning: result)
                    } else {
                        call.reply.resume(throwing: RPCFault.error(in: message))
                    }
                } else if let params = message["params"] as? [String: Any], let token = Token(params["subscription"]),
                          let result = params["result"] {
                    streams[token]?.yield(result)
                }
                scheduleIdleClose()
            }
        } catch {
            if socket === ws {
                close()
            }
        }
    }

    func verifyGenesis(_ id: ChainID) async throws {
        guard let hash = try await request("chain_getBlockHash", [0], timeout: 6) as? String,
              hash.lowercased() == "0x" + id.rawValue else {
            throw WalletError.network("Endpoint belongs to a different network.")
        }
    }

    func watch(_ extrinsic: String) async throws -> Subscription {
        let pair = Stream.makeStream()
        let result = try await request(
            "author_submitAndWatchExtrinsic",
            [extrinsic],
            timeout: 15,
            stream: pair.continuation
        )
        guard let token = Token(result) else { throw WalletError.network("Invalid subscription response.") }
        let cancel: @Sendable () async -> Void = { await self.unwatch(token) }
        pair.continuation.onTermination = { _ in Task { await cancel() } }
        return Subscription(events: pair.stream, cancel: cancel)
    }

    private func unwatch(_ token: Token) async {
        guard let stream = streams.removeValue(forKey: token) else { return }
        stream.finish()
        _ = try? await request("author_unwatchExtrinsic", [token.value], timeout: 5)
        close()
    }

    private func scheduleIdleClose() {
        guard pending.isEmpty, streams.isEmpty else { return }
        idle?.cancel()
        idle = Task {
            try? await Task.sleep(for: .seconds(45))
            if !Task.isCancelled {
                close()
            }
        }
    }

    func close() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        let error = WalletError.network("The RPC connection closed.")
        for id in Array(pending.keys) {
            fail(id, error)
        }
        for stream in streams.values {
            stream.finish(throwing: error)
        }
        streams.removeAll()
        idle?.cancel()
    }
}

struct RPCFault: Error {
    let message: String
    static func error(in reply: [String: Any]) -> Error {
        guard let error = reply["error"] as? [String: Any], error["code"] is NSNumber,
              let message = error["message"] as? String else {
            return WalletError.network("Malformed JSON-RPC reply.")
        }
        return RPCFault(message: String(message.prefix(240)))
    }
}
