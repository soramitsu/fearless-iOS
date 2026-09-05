import Foundation

protocol LegacyTonConnectBridgeTransporting {
    func manifest(at url: URL) async throws -> LegacyTonConnectManifest
    func send(_ data: Data, session: LegacyTonConnectSession, bridge: URL, topic: String) async throws
    func listen(
        session: LegacyTonConnectSession, context: LegacyTonConnectSessionContext,
        receive: @escaping (Data, String?) async throws -> Void
    ) async throws
}

struct LegacyTonConnectBridgeEnvelope: Decodable {
    let from: String
    let message: String
}

struct LegacyTonConnectServerEvent {
    let id: String?
    let data: Data
}

struct LegacyTonConnectEventParser {
    private var line = Data()
    private var dataLines: [String] = []
    private var eventId: String?
    private var eventName: String?
    private var size = 0

    mutating func append(_ byte: UInt8) throws -> LegacyTonConnectServerEvent? {
        guard byte == 10 else {
            guard line.count < 100_000 else { throw LegacyTonConnectError.invalidRequest }
            line.append(byte)
            return nil
        }
        if line.last == 13 { line.removeLast() }
        guard let value = String(data: line, encoding: .utf8) else { throw LegacyTonConnectError.invalidRequest }
        line.removeAll(keepingCapacity: true)
        if value.isEmpty {
            defer {
                dataLines.removeAll()
                eventId = nil
                eventName = nil
                size = 0
            }
            guard !dataLines.isEmpty, eventName == nil || eventName == "message" else { return nil }
            return LegacyTonConnectServerEvent(id: eventId, data: Data(dataLines.joined(separator: "\n").utf8))
        }
        if value.hasPrefix(":") { return nil }
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        var field = parts.count > 1 ? String(parts[1]) : ""
        if field.hasPrefix(" ") { field.removeFirst() }
        switch parts[0] {
        case "data":
            size += field.utf8.count
            guard size <= 100_000 else { throw LegacyTonConnectError.invalidRequest }
            dataLines.append(field)
        case "id":
            guard field.utf8.count <= 256, !field.contains("\u{0}") else { throw LegacyTonConnectError.invalidRequest }
            eventId = field
        case "event": eventName = field
        default: break
        }
        return nil
    }
}

final class LegacyTonConnectBridgeTransport: NSObject, LegacyTonConnectBridgeTransporting, URLSessionTaskDelegate {
    private let configuration: URLSessionConfiguration

    init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration.copy() as? URLSessionConfiguration ?? .ephemeral
        self.configuration.timeoutIntervalForRequest = 45
        self.configuration.timeoutIntervalForResource = 600
        self.configuration.urlCache = nil
        self.configuration.httpCookieStorage = nil
        super.init()
    }

    static func validBridgeURL(_ url: URL) -> Bool {
        guard LegacyTonConnectProtocol.origin(url) != nil,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.query == nil, parts.fragment == nil,
              !parts.percentEncodedPath.contains("%"),
              !parts.path.contains("\\"),
              !parts.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { return false }
        return true
    }

    static func endpoint(bridge: URL, method: String, query: [URLQueryItem]) throws -> URL {
        guard validBridgeURL(bridge), ["events", "message"].contains(method),
              var parts = URLComponents(url: bridge, resolvingAgainstBaseURL: false) else {
            throw LegacyTonConnectError.unavailableBridge
        }
        parts.path = parts.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        parts.path = "/" + (parts.path.isEmpty ? "" : parts.path + "/") + method
        parts.queryItems = query
        guard let url = parts.url else { throw LegacyTonConnectError.unavailableBridge }
        return url
    }

    func manifest(at url: URL) async throws -> LegacyTonConnectManifest {
        guard LegacyTonConnectProtocol.origin(url) != nil else { throw LegacyTonConnectError.invalidRequest }
        let data = try await fetch(URLRequest(url: url), maximumBytes: 32768)
        let manifest = try JSONDecoder().decode(LegacyTonConnectManifest.self, from: data).validated()
        // Released clients and TonConnect permit a manifest on a separate HTTPS CDN.
        // The validated application URL remains the session and proof identity.
        return manifest
    }

    func send(_ data: Data, session: LegacyTonConnectSession, bridge: URL, topic: String) async throws {
        let encrypted = try session.encrypt(data)
        let url = try Self.endpoint(bridge: bridge, method: "message", query: [
            .init(name: "client_id", value: session.publicKey.map { String(format: "%02x", $0) }.joined()),
            .init(name: "to", value: session.clientId), .init(name: "ttl", value: "300"),
            .init(name: "topic", value: topic)
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(encrypted.base64EncodedString().utf8)
        _ = try await fetch(request, maximumBytes: 8192)
    }

    func listen(
        session: LegacyTonConnectSession, context: LegacyTonConnectSessionContext,
        receive: @escaping (Data, String?) async throws -> Void
    ) async throws {
        _ = try session.validated()
        var query = [URLQueryItem(name: "client_id", value: session.publicKey.map { String(format: "%02x", $0) }.joined())]
        if let lastId = context.lastEventId { query.append(.init(name: "last_event_id", value: lastId)) }
        let url = try Self.endpoint(bridge: context.bridgeURL, method: "events", query: query)
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let transport = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { transport.invalidateAndCancel() }
        let (bytes, response) = try await transport.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw LegacyTonConnectError.transportFailed
        }
        var parser = LegacyTonConnectEventParser()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard let event = try parser.append(byte) else { continue }
            guard let envelope = try? JSONDecoder().decode(LegacyTonConnectBridgeEnvelope.self, from: event.data),
                  let ciphertext = Data(base64Encoded: envelope.message),
                  let plaintext = try? session.decrypt(ciphertext, from: envelope.from) else { continue }
            try await receive(plaintext, event.id)
        }
    }

    private func fetch(_ request: URLRequest, maximumBytes: Int) async throws -> Data {
        let transport = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { transport.invalidateAndCancel() }
        let (bytes, response) = try await transport.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
              response.expectedContentLength <= maximumBytes else { throw LegacyTonConnectError.transportFailed }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maximumBytes else { throw LegacyTonConnectError.invalidRequest }
            data.append(byte)
        }
        return data
    }

    func urlSession(
        _: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
