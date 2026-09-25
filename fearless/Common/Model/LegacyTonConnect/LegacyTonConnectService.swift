import Foundation
import SoraKeystore

struct LegacyTonConnectRPCOutcome {
    let response: Data
    let messageHashHex: String?
}

protocol LegacyTonConnectRequestHandling: AnyObject {
    func process(
        session: LegacyTonConnectSession, network: String,
        request: LegacyTonConnectRPCRequest
    ) async throws -> LegacyTonConnectRPCOutcome
    func acknowledge(
        session: LegacyTonConnectSession, network: String,
        request: LegacyTonConnectRPCRequest, messageHashHex: String
    ) async throws
}

actor LegacyTonConnectService {
    private let store: LegacyTonConnectSessionStoring
    private let replies: LegacyTonConnectReplyStore
    private let transport: LegacyTonConnectBridgeTransporting
    private let legacyEventId: () -> String?
    private weak var handler: LegacyTonConnectRequestHandling?
    private var listeners: [String: Task<Void, Never>] = [:]
    private var processing: Set<String> = []

    init(
        store: LegacyTonConnectSessionStoring = LegacyTonConnectStore(),
        replies: LegacyTonConnectReplyStore = LegacyTonConnectReplyStore(),
        transport: LegacyTonConnectBridgeTransporting = LegacyTonConnectBridgeTransport(),
        legacyEventId: @escaping () -> String? = {
            SettingsManager.shared.value(of: String.self, for: "ton.connect.last.event.key")
        }
    ) {
        self.store = store
        self.replies = replies
        self.transport = transport
        self.legacyEventId = legacyEventId
    }

    func set(handler: LegacyTonConnectRequestHandling) {
        self.handler = handler
    }

    func sessions(walletId: String) async throws -> [LegacyTonConnectSession] {
        try await store.sessions().filter { $0.walletId == walletId }
    }

    func context(for session: LegacyTonConnectSession, selectedNetwork: String) async throws -> LegacyTonConnectSessionContext {
        if let stored = try replies.context(sessionId: session.identifier) { return stored }
        // Earlier releases selected a bridge using the retained TON environment toggle.
        // Bind that context once before starting a restored session; never regenerate keys.
        let context = LegacyTonConnectSessionContext(
            bridgeURL: session.connectionType == "http" ? try await store.bridgeURL(network: selectedNetwork) : session.appUrl,
            network: selectedNetwork, lastEventId: session.connectionType == "http" ? legacyEventId() : nil
        )
        try replies.save(context: context, sessionId: session.identifier)
        return context
    }

    func start(selectedNetwork: String) async {
        guard let sessions = try? await store.sessions() else { return }
        let validIds = Set(sessions.filter { $0.connectionType == "http" }.map(\.identifier))
        for (id, task) in listeners where !validIds.contains(id) {
            task.cancel()
            listeners.removeValue(forKey: id)
        }
        for session in sessions where session.connectionType == "http" && listeners[session.identifier] == nil {
            listeners[session.identifier] = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    do {
                        guard try await self.store.sessions().contains(session) else { return }
                        let context = try await self.context(for: session, selectedNetwork: selectedNetwork)
                        try await self.transport.listen(session: session, context: context) { [weak self] data, eventId in
                            guard let self else { return }
                            do {
                                let reply = try await self.handle(data, session: session, network: context.network)
                                let method = (try? LegacyTonConnectRPCRequest.decode(data).method) ?? "sendTransaction"
                                try await self.transport.send(reply, session: session, bridge: context.bridgeURL, topic: method)
                            } catch LegacyTonConnectError.invalidRequest {
                                // An authenticated malformed request without a usable ID
                                // cannot receive a reply and must not block later events.
                            }
                            if let eventId {
                                var updated = context
                                updated.lastEventId = eventId
                                try self.replies.save(context: updated, sessionId: session.identifier)
                            }
                        }
                    } catch {
                        // An offline/locked/malformed session cannot delay wallet startup.
                    }
                    do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                }
            }
        }
    }

    func stop() {
        listeners.values.forEach { $0.cancel() }
        listeners.removeAll()
    }

    func save(session: LegacyTonConnectSession, context: LegacyTonConnectSessionContext) async throws {
        try await store.save(session)
        try replies.save(context: context, sessionId: session.identifier)
    }

    func disconnect(_ session: LegacyTonConnectSession) async throws {
        // This is only called for an authenticated disconnect or an explicit UI action.
        try await store.remove(session)
        listeners.removeValue(forKey: session.identifier)?.cancel()
    }

    func handle(_ data: Data, session: LegacyTonConnectSession, network: String) async throws -> Data {
        _ = try session.validated()
        guard try await store.sessions().contains(session) else { throw LegacyTonConnectError.invalidSession }
        guard data.count <= LegacyTonConnectProtocol.maximumMessageBytes,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestId = object["id"] as? String, !requestId.isEmpty, requestId.utf8.count <= 128 else {
            throw LegacyTonConnectError.invalidRequest
        }
        let canonical = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        if let saved = try replies.reply(sessionId: session.identifier, requestId: requestId, request: canonical) {
            if let hash = saved.messageHashHex {
                let request = try LegacyTonConnectRPCRequest.decode(data)
                try await handler?.acknowledge(session: session, network: network, request: request, messageHashHex: hash)
            }
            return saved.response
        }
        let request: LegacyTonConnectRPCRequest
        do {
            request = try LegacyTonConnectRPCRequest.decode(data)
        } catch {
            let code: Int
            if case LegacyTonConnectError.unsupportedRequest = error { code = 400 } else { code = 1 }
            let response = try LegacyTonConnectProtocol.response(id: requestId, errorCode: code, message: "Unsupported or invalid TonConnect request")
            try replies.save(response: response, sessionId: session.identifier, requestId: requestId, request: canonical)
            return response
        }
        let processingId = session.identifier + "\u{0}" + request.id
        guard processing.insert(processingId).inserted else { throw LegacyTonConnectError.busy }
        defer { processing.remove(processingId) }
        if request.method == "disconnect" {
            let response = try LegacyTonConnectProtocol.response(id: request.id, result: "")
            try replies.save(response: response, sessionId: session.identifier, requestId: request.id, request: canonical)
            // Allow the authenticated disconnect reply to leave before its
            // listener observes the removed row and exits on the next cycle.
            try await store.remove(session)
            return response
        }
        guard let handler else { throw LegacyTonConnectError.unavailableWallet }
        let outcome: LegacyTonConnectRPCOutcome
        do {
            outcome = try await handler.process(session: session, network: network, request: request)
        } catch let error as LegacyTonConnectError {
            let code: Int
            switch error {
            case .invalidRequest, .expiredRequest: code = 1
            case .unsupportedRequest: code = 400
            default: throw error
            }
            outcome = LegacyTonConnectRPCOutcome(
                response: try LegacyTonConnectProtocol.response(id: request.id, errorCode: code, message: error.localizedDescription),
                messageHashHex: nil
            )
        }
        // A signing/broadcast result cannot be acknowledged until this write succeeds.
        try replies.save(
            response: outcome.response,
            messageHashHex: outcome.messageHashHex,
            sessionId: session.identifier,
            requestId: request.id,
            request: canonical
        )
        if let hash = outcome.messageHashHex {
            try await handler.acknowledge(session: session, network: network, request: request, messageHashHex: hash)
        }
        return outcome.response
    }
}
