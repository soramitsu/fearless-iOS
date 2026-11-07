import CryptoKit
import Foundation

public extension WalletConnectClient {
    /// Subscribes to a dApp's pairing link. Its proposal arrives as `Event.sessionProposal`.
    func pair(uri: WalletConnectURI) async throws {
        guard started else {
            throw ClientError.notStarted
        }
        let now = clock.nowSeconds
        if let expiry = uri.expiryTimestamp, Int64(clamping: expiry) <= now {
            throw ClientError.pairingExpired
        }
        if state.pairings.contains(where: { $0.topic == uri.topic && $0.active }) {
            throw ClientError.pairingAlreadyActive
        }
        // A pairing's topic is whatever the dApp chose: the SHA-256 of the key in most SDKs, random in others.
        guard let symKey = Hex.decodeKey(uri.symKey), Hex.isKey(uri.topic) else {
            throw WalletConnectURI.Error.invalid("pairing key")
        }
        // A link must never replace the key of a live session or of another pairing: whoever made the link could then
        // read and write that topic. Opening the same pending link again is harmless and changes nothing.
        if state.sessions.contains(where: { $0.topic == uri.topic }) {
            throw ClientError.topicInUse
        }
        if let existingKey = secrets.keys[uri.topic], Hex.decodeKey(existingKey) != symKey {
            throw ClientError.topicInUse
        }

        let expiry = min(uri.expiryTimestamp.map { Int64(clamping: $0) } ?? now + Int64(SignProtocol.fiveMinutes), now + Int64(SignProtocol.thirtyDays))
        let pairing = StoredPairing(
            topic: uri.topic,
            expiry: expiry,
            relayProtocol: uri.relayProtocol,
            active: false,
            peerMetadata: nil,
            methods: uri.methods,
            importedFrom: nil
        )

        secrets.keys[uri.topic] = uri.symKey
        try saveSecrets()
        state.pairings.removeAll { $0.topic == uri.topic }
        state.pairings.append(pairing)
        state.forgottenTopics.removeAll { $0 == uri.topic }
        try saveState()
        scheduleSweep()

        try await relay.subscribe([uri.topic])
    }

    /// Approves a dApp's proposal: settles a new session in which Fearless is the controller.
    @discardableResult
    func approve(
        proposalId: Int64,
        namespaces: [String: SessionNamespace],
        sessionProperties: [String: String]? = nil
    ) async throws -> Session {
        guard started else {
            throw ClientError.notStarted
        }
        guard let proposal = state.proposals.first(where: { $0.id == proposalId }) else {
            throw ClientError.proposalNotFound
        }
        let now = clock.nowSeconds
        guard proposal.expiry > now else {
            state.proposals.removeAll { $0.id == proposalId }
            persist()
            throw ClientError.proposalExpired
        }
        guard
            PeerMessageReader.isValidGrant(namespaces),
            PeerMessageReader.covers(required: proposal.requiredNamespaces, granted: namespaces)
        else {
            throw ClientError.invalidNamespaces
        }
        guard key(for: proposal.pairingTopic) != nil else {
            throw ClientError.noMatchingKey
        }
        guard let proposerKey = Hex.decodeKey(proposal.proposer.publicKey) else {
            throw ClientError.noMatchingKey
        }

        let selfKey = Curve25519.KeyAgreement.PrivateKey()
        let selfPublicKey = Hex.encode(selfKey.publicKey.rawRepresentation)
        let symKey = try WalletConnectCrypto.deriveSymmetricKey(privateKey: selfKey, peerPublicKey: proposerKey)
        let topic = WalletConnectCrypto.topic(forSymmetricKey: symKey)
        let expiry = now + Int64(SignProtocol.sevenDays)
        let relayProtocol = proposal.relayProtocol
        let settleId = identifiers.next(now: clock.now())
        let session = StoredSession(
            topic: topic,
            pairingTopic: proposal.pairingTopic,
            relayProtocol: relayProtocol,
            expiry: expiry,
            acknowledged: false,
            controller: selfPublicKey,
            namespaces: namespaces,
            requiredNamespaces: proposal.requiredNamespaces,
            optionalNamespaces: proposal.optionalNamespaces,
            sessionProperties: sessionProperties,
            selfParticipant: StoredParticipant(publicKey: selfPublicKey, metadata: configuration.metadata),
            peer: proposal.proposer,
            importedFrom: nil
        )

        secrets.keys[topic] = Hex.encode(symKey)
        try saveSecrets()
        state.sessions.append(session)
        state.settlements[topic] = settleId
        state.proposals.removeAll { $0.id == proposalId }
        if let index = state.pairings.firstIndex(where: { $0.topic == proposal.pairingTopic }) {
            state.pairings[index].active = true
            state.pairings[index].expiry = now + Int64(SignProtocol.thirtyDays)
            state.pairings[index].peerMetadata = proposal.proposer.metadata
        }
        try saveState()

        let relayObject = JSONValue.object(["protocol": .string(relayProtocol)])
        var settleParams: [String: JSONValue] = [
            "relay": relayObject,
            "namespaces": .object(namespaces.mapValues(\.json)),
            "expiry": .int(expiry),
            "controller": .object([
                "publicKey": .string(selfPublicKey),
                "metadata": configuration.metadata.json
            ])
        ]
        if let sessionProperties {
            settleParams["sessionProperties"] = .object(sessionProperties.mapValues(JSONValue.string))
        }

        do {
            try await relay.subscribe([topic])
            try await publish(
                .response(
                    id: proposal.id,
                    result: .response(AnyCodable(json: .object([
                        "relay": relayObject,
                        "responderPublicKey": .string(selfPublicKey)
                    ])))
                ),
                on: proposal.pairingTopic,
                options: SignProtocol.proposeResponse
            )
            try await publish(
                .request(id: settleId, method: "wc_sessionSettle", params: .object(settleParams)),
                on: topic,
                options: SignProtocol.settleRequest
            )
        } catch {
            await forgetSession(topic: topic)
            throw error
        }

        publishSessions()
        scheduleSweep()
        return session.publicSession
    }

    /// Refuses a dApp's proposal and tells the dApp why.
    func reject(proposalId: Int64, reason: RejectionReason) async throws {
        guard started else {
            throw ClientError.notStarted
        }
        guard let proposal = state.proposals.first(where: { $0.id == proposalId }) else {
            throw ClientError.proposalNotFound
        }
        state.proposals.removeAll { $0.id == proposalId }
        try saveState()
        try await publish(
            .response(id: proposalId, result: .error(JSONRPCError(code: reason.code, message: reason.message))),
            on: proposal.pairingTopic,
            options: SignProtocol.proposeReject
        )
    }

    /// Answers a dApp's request in a session.
    func respond(topic: String, requestId: Int64, response: RPCResult) async throws {
        guard started else {
            throw ClientError.notStarted
        }
        guard let session = state.sessions.first(where: { $0.topic == topic }), session.isWalletSession else {
            throw ClientError.sessionNotFound
        }
        // Only a request the dApp still waits for is answered. A signature for one that expired or was already
        // answered would reach nobody who asked for it.
        guard isPending(topic: topic, requestId: requestId) else {
            state.requests.removeAll { $0.topic == topic && $0.id == requestId }
            persist()
            throw ClientError.requestNotFound
        }
        state.requests.removeAll { $0.topic == topic && $0.id == requestId }
        try saveState()
        try await publish(.response(id: requestId, result: response), on: topic, options: SignProtocol.sessionRequestResponse)
    }

    /// Ends a session or a pairing: the keys are forgotten here first, then the peer is told. Ending it here does not
    /// depend on the network: if the peer cannot be told, it finds out when the wallet no longer answers.
    func disconnect(topic: String) async throws {
        guard started else {
            throw ClientError.notStarted
        }
        let isSession = state.sessions.contains { $0.topic == topic }
        let isPairing = state.pairings.contains { $0.topic == topic }
        guard isSession || isPairing else {
            throw ClientError.sessionNotFound
        }

        let method = isSession ? "wc_sessionDelete" : "wc_pairingDelete"
        let options = isSession ? SignProtocol.deleteRequest : SignProtocol.pairingDeleteRequest
        let reason = SignError.userDisconnected
        let message = RPCMessage.request(
            id: identifiers.next(now: clock.now()),
            method: method,
            params: .object(["code": .int(reason.code), "message": .string(reason.message)])
        )
        let envelope = try key(for: topic).map { try WalletConnectCrypto.seal(Data(message.text.utf8), symmetricKey: $0) }

        if isSession {
            await forgetSession(topic: topic)
            emit(.sessionDeleted(topic: topic))
        } else {
            await forgetPairing(topic: topic)
        }

        if let envelope {
            do {
                try await relay.publish(topic: topic, message: envelope, ttl: options.ttl, tag: options.tag, prompt: options.prompt)
            } catch {
                logger.warning("WalletConnect could not tell the peer it was disconnected: \(error)")
            }
        }
    }

    /// Ends every session and every pairing, as logging out of the wallet does: each is forgotten here, then its peer
    /// is told. Their pending proposals and requests go with them.
    func disconnectAll() async throws {
        guard started else {
            throw ClientError.notStarted
        }
        var firstError: Error?
        let topics = state.sessions.map(\.topic) + state.pairings.map(\.topic)
        for topic in topics {
            do {
                try await disconnect(topic: topic)
            } catch ClientError.sessionNotFound {
                // Already ended while the others were.
            } catch {
                // The rest still end.
                firstError = firstError ?? error
            }
        }
        if let firstError {
            throw firstError
        }
    }

    /// Checks that the peer of a session or pairing still answers.
    func ping(topic: String) async throws {
        guard started else {
            throw ClientError.notStarted
        }
        let isSession = state.sessions.contains { $0.topic == topic }
        guard isSession || state.pairings.contains(where: { $0.topic == topic }) else {
            throw ClientError.sessionNotFound
        }
        let id = identifiers.next(now: clock.now())
        let response = expectResponse(id: id, topic: topic, timeout: 30)
        do {
            try await publish(
                .request(id: id, method: isSession ? "wc_sessionPing" : "wc_pairingPing", params: .object([:])),
                on: topic,
                options: isSession ? SignProtocol.pingRequest : SignProtocol.pairingPingRequest
            )
        } catch {
            failWaiter(id: id, error: error)
            throw error
        }
        if case let .error(error) = try await response.value() {
            throw ClientError.peerError(code: error.code, message: error.message)
        }
    }
}

extension WalletConnectClient {
    /// Forgets a session: its record, its key and its pending requests; an earlier SDK's records of it too.
    func forgetSession(topic: String) async {
        guard let index = state.sessions.firstIndex(where: { $0.topic == topic }) else {
            return
        }
        let session = state.sessions.remove(at: index)
        state.requests.removeAll { $0.topic == topic }
        state.settlements[topic] = nil
        state.forgottenTopics.append(topic)
        persist()

        secrets.keys[topic] = nil
        do {
            try saveSecrets()
        } catch {
            logger.error("WalletConnect could not remove a session key: \(error)")
        }

        if session.importedFrom != nil {
            let records = LegacyWalletConnectImporter.records(forSession: session)
            legacyStorage?.removeRecords(keys: records.keys, keychainAccounts: records.keychainAccounts)
        }

        failWaiting(ClientError.sessionNotFound, topic: topic)
        publishSessions()
        await relay.unsubscribe(topic)
    }

    func forgetPairing(topic: String) async {
        guard let index = state.pairings.firstIndex(where: { $0.topic == topic }) else {
            return
        }
        let pairing = state.pairings.remove(at: index)
        state.proposals.removeAll { $0.pairingTopic == topic }
        state.forgottenTopics.append(topic)
        persist()

        secrets.keys[topic] = nil
        do {
            try saveSecrets()
        } catch {
            logger.error("WalletConnect could not remove a pairing key: \(error)")
        }

        if pairing.importedFrom != nil {
            let records = LegacyWalletConnectImporter.records(forPairing: pairing)
            legacyStorage?.removeRecords(keys: records.keys, keychainAccounts: records.keychainAccounts)
        }

        failWaiting(ClientError.sessionNotFound, topic: topic)
        await relay.unsubscribe(topic)
    }
}
