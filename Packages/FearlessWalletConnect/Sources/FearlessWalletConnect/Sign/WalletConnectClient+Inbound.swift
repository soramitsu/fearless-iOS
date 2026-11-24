import Foundation

extension WalletConnectClient {
    struct Delivery {
        let message: String
        let attestation: String?
    }

    /// Handles one message the relay delivered. A message is handled once, however often the relay delivers it.
    func process(_ relayMessage: RelayMessage) async {
        guard started else {
            return
        }
        let hash = WalletConnectCrypto.messageHash(relayMessage.message)
        guard !hasSeen(hash), let key = key(for: relayMessage.topic) else {
            return
        }

        guard
            let plaintext = try? WalletConnectCrypto.open(relayMessage.message, symmetricKey: key),
            let json = try? JSONParser.parse(plaintext),
            let message = RPCMessage(json: json)
        else {
            // Not for this key, or not a type 0 envelope: nothing to act on.
            return
        }

        markSeen(hash)
        let delivery = Delivery(message: relayMessage.message, attestation: relayMessage.attestation)
        switch message {
        case let .request(id, method, params):
            await onRequest(topic: relayMessage.topic, id: id, method: method, params: params, delivery: delivery)
        case let .response(id, result):
            await onResponse(topic: relayMessage.topic, id: id, result: result)
        }
        persist()
    }

    private func onRequest(topic: String, id: Int64, method: String, params: JSONValue, delivery: Delivery) async {
        let ok = AnyCodable(json: .bool(true))

        if let session = state.sessions.first(where: { $0.topic == topic }) {
            switch method {
            case "wc_sessionRequest":
                await onSessionRequest(session: session, id: id, params: params, delivery: delivery)
            case "wc_sessionPing":
                await reply(.response(id: id, result: .response(ok)), on: topic, options: SignProtocol.pingResponse)
                emit(.sessionPinged(topic: topic))
            case "wc_sessionDelete":
                await reply(.response(id: id, result: .response(ok)), on: topic, options: SignProtocol.deleteResponse)
                await forgetSession(topic: topic)
                emit(.sessionDeleted(topic: topic))
            case "wc_sessionEvent":
                // Events go from the wallet to the dApp; one from the dApp changes nothing.
                await reply(.response(id: id, result: .response(ok)), on: topic, options: SignProtocol.eventResponse)
            case "wc_sessionUpdate":
                // Only the controller may change a session, and in these sessions Fearless is the controller.
                await reply(
                    .response(id: id, result: .error(SignError.unauthorizedUpdateRequest())),
                    on: topic,
                    options: SignProtocol.updateResponse
                )
            case "wc_sessionExtend":
                await reply(
                    .response(id: id, result: .error(SignError.unauthorizedExtendRequest())),
                    on: topic,
                    options: SignProtocol.extendResponse
                )
            default:
                await reply(
                    .response(id: id, result: .error(SignError.unsupportedWcMethod(String(method.prefix(64))))),
                    on: topic,
                    options: SignProtocol.unregisteredMethod
                )
            }
            return
        }

        guard state.pairings.contains(where: { $0.topic == topic }) else {
            return
        }

        switch method {
        case "wc_sessionPropose":
            await onSessionPropose(pairingTopic: topic, id: id, params: params, delivery: delivery)
        case "wc_pairingPing":
            await reply(.response(id: id, result: .response(ok)), on: topic, options: SignProtocol.pairingPingResponse)
        case "wc_pairingDelete":
            await reply(.response(id: id, result: .response(ok)), on: topic, options: SignProtocol.pairingDeleteResponse)
            await forgetPairing(topic: topic)
        default:
            // One-click authentication and other pairing methods are not offered; a dApp falls back to its proposal.
            break
        }
    }

    private func onResponse(topic: String, id: Int64, result: RPCResult) async {
        if resolveWaiter(id: id, topic: topic, result: result) {
            return
        }

        guard state.settlements[topic] == id else {
            return
        }
        state.settlements[topic] = nil

        switch result {
        case .response:
            if let index = state.sessions.firstIndex(where: { $0.topic == topic }) {
                state.sessions[index].acknowledged = true
                persist()
                publishSessions()
            }
        case .error:
            // The dApp refused the settlement.
            await forgetSession(topic: topic)
            emit(.sessionDeleted(topic: topic))
        }
    }

    // MARK: - Proposals

    func readProposal(pairingTopic: String, id: Int64, params: JSONValue) -> StoredProposal? {
        guard id > 0, params.objectValue != nil, let proposer = PeerMessageReader.participant(params["proposer"]) else {
            return nil
        }
        guard
            let required = PeerMessageReader.proposalNamespaces(params["requiredNamespaces"]),
            let optional = PeerMessageReader.proposalNamespaces(params["optionalNamespaces"])
        else {
            return nil
        }

        let sessionProperties: [String: String]?
        switch PeerMessageReader.properties(params["sessionProperties"]) {
        case .absent:
            sessionProperties = nil
        case let .valid(properties):
            sessionProperties = properties
        case .invalid:
            return nil
        }

        var relayProtocol = "irn"
        if let relays = params["relays"], !relays.isNull {
            guard let list = relays.arrayValue, list.count <= 8 else {
                return nil
            }
            let protocols = list.map(PeerMessageReader.relayProtocol)
            guard !protocols.contains(nil) else {
                return nil
            }
            relayProtocol = protocols.first.flatMap { $0 } ?? "irn"
        }

        let now = clock.nowSeconds
        let claimed = params["expiryTimestamp"]?.int64Value
        let expiry = claimed.map { min($0, now + Int64(SignProtocol.thirtyDays)) } ?? now + Int64(SignProtocol.fiveMinutes)

        return StoredProposal(
            id: id,
            // The topic it arrived on, not whatever the message claims.
            pairingTopic: pairingTopic,
            expiry: expiry,
            relayProtocol: relayProtocol,
            proposer: proposer,
            requiredNamespaces: required,
            optionalNamespaces: optional.isEmpty ? nil : optional,
            sessionProperties: sessionProperties
        )
    }

    private func onSessionPropose(pairingTopic: String, id: Int64, params: JSONValue, delivery: Delivery) async {
        guard let proposal = readProposal(pairingTopic: pairingTopic, id: id, params: params) else {
            logger.info("WalletConnect ignored a proposal it could not read")
            return
        }
        guard proposal.expiry > clock.nowSeconds, !state.proposals.contains(where: { $0.id == proposal.id }) else {
            return
        }

        state.proposals.append(proposal)
        if state.proposals.count > Self.maxPendingProposals {
            state.proposals.removeFirst(state.proposals.count - Self.maxPendingProposals)
        }
        if let index = state.pairings.firstIndex(where: { $0.topic == pairingTopic }) {
            state.pairings[index].peerMetadata = proposal.proposer.metadata
        }
        persist()
        scheduleSweep()

        let context = await verifyContext(metadata: proposal.proposer.metadata, delivery: delivery)
        guard state.proposals.contains(where: { $0.id == proposal.id }) else {
            return
        }
        emit(.sessionProposal(proposal.publicProposal, context))
    }

    // MARK: - Requests

    private func onSessionRequest(session: StoredSession, id: Int64, params: JSONValue, delivery: Delivery) async {
        let topic = session.topic
        let refuse = { (error: JSONRPCError) async in
            await self.reply(.response(id: id, result: .error(error)), on: topic, options: SignProtocol.sessionRequestResponse)
        }

        // Fearless answers only in sessions it settled as the wallet, and only once the dApp confirmed them.
        guard session.isWalletSession else {
            await refuse(SignError.unauthorizedMethod("wc_sessionRequest"))
            return
        }
        guard session.acknowledged else {
            await refuse(SignError.unauthorizedMethod("session is not settled"))
            return
        }

        guard
            let body = params["request"], body.objectValue != nil,
            let method = body["method"]?.stringValue, (1 ... 256).contains(method.utf8.count),
            let chainString = params["chainId"]?.stringValue, let chain = Blockchain(chainString)
        else {
            await refuse(SignError.invalidMethod())
            return
        }

        guard session.grants(chain: chain) else {
            await refuse(SignError.unsupportedChains(chain.absoluteString))
            return
        }
        guard session.permits(method: method, on: chain) else {
            await refuse(SignError.unsupportedMethods(String(method.prefix(64))))
            return
        }

        if state.requests.contains(where: { $0.topic == topic && $0.id == id }) {
            return
        }

        let now = clock.nowSeconds
        var expiry = now + Int64(SignProtocol.fifteenMinutes)
        if let claimed = body["expiryTimestamp"], !claimed.isNull {
            guard let value = claimed.int64Value else {
                await refuse(SignError.invalidMethod())
                return
            }
            expiry = min(value, now + Int64(SignProtocol.sevenDays))
        }
        guard expiry > now else {
            // The dApp no longer waits for it.
            return
        }

        state.requests.append(StoredRequest(id: id, topic: topic, expiry: expiry))
        if state.requests.count > Self.maxPendingRequests {
            state.requests.removeFirst(state.requests.count - Self.maxPendingRequests)
        }
        persist()
        scheduleSweep()

        let context = await verifyContext(metadata: session.peer.metadata, delivery: delivery)
        guard state.sessions.contains(where: { $0.topic == topic }) else {
            return
        }
        let request = Request(
            id: id,
            topic: topic,
            method: method,
            params: AnyCodable(json: body["params"] ?? .null),
            chainId: chain,
            expiryTimestamp: UInt64(clamping: expiry)
        )
        emit(.sessionRequest(request, context))
    }

    func verifyContext(metadata: AppMetadata, delivery: Delivery) async -> VerifyContext {
        guard configuration.verifiesOrigins else {
            return VerifyContext(
                origin: metadata.url,
                validation: .unknown,
                verifyUrl: VerifyClient.trustedServer(metadata.verifyUrl)
            )
        }
        return await verify.context(metadata: metadata, message: delivery.message, attestation: delivery.attestation)
    }
}
