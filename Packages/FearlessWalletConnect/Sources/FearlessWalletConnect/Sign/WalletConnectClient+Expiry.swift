import Foundation

extension WalletConnectClient {
    /// Wakes the client at the next deadline: a proposal, request, session or pairing that runs out.
    func scheduleSweep() {
        sweepTask?.cancel()
        guard started else {
            return
        }
        let deadlines = state.proposals.map(\.expiry)
            + state.requests.map(\.expiry)
            + state.sessions.map(\.expiry)
            + state.pairings.map(\.expiry)
        let nowSeconds = clock.now().timeIntervalSince1970
        let delay = deadlines.min().map { max(TimeInterval($0) - nowSeconds, 0) + 0.05 } ?? Self.maxSweepDelay
        let sleep = clock.sleep
        sweepTask = Task { [weak self] in
            do {
                try await sleep(min(delay, Self.maxSweepDelay))
            } catch {
                return
            }
            await self?.sweep()
        }
    }

    /// Ends what ran out, and reports it.
    func sweep() async {
        guard started else {
            return
        }
        let now = clock.nowSeconds
        var changed = false

        for proposal in state.proposals where proposal.expiry <= now {
            state.proposals.removeAll { $0.id == proposal.id }
            changed = true
            emit(.proposalExpired(id: proposal.id))
        }

        for request in state.requests where request.expiry <= now {
            state.requests.removeAll { $0 == request }
            changed = true
            emit(.requestExpired(id: request.id, topic: request.topic))
        }

        for session in state.sessions where session.expiry <= now {
            await forgetSession(topic: session.topic)
            emit(.sessionDeleted(topic: session.topic))
        }

        for pairing in state.pairings where pairing.expiry <= now {
            await forgetPairing(topic: pairing.topic)
        }

        let dayAgo = now - Int64(SignProtocol.oneDay)
        let seenCount = state.seen.count
        state.seen.removeAll { $0.at < dayAgo }
        changed = changed || state.seen.count != seenCount

        if changed {
            persist()
        }
        scheduleSweep()
    }
}
