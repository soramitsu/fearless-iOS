import Foundation

struct MutationAuthorizationHighWater: Codable, Equatable {
    let revision: Int64
    let payloadSha256: String
    let maximumWallSeconds: Int64

    var isValid: Bool {
        revision > 0 && MutationAuthorizationVerifier.matches(payloadSha256, "[0-9a-f]{64}") &&
            maximumWallSeconds >= 0 && maximumWallSeconds <= 253_402_300_799
    }
}

protocol MutationAuthorizationHighWaterStoring {
    func load() throws -> MutationAuthorizationHighWater?
    /// Atomically persist before granting. An error must never grant authority.
    /// One process-wide authority owns this store; no app extension may write it.
    func save(_ value: MutationAuthorizationHighWater) throws
}

struct MutationAuthorizationClock {
    let wallSeconds: Int64
    /// Must advance across device sleep (mach_continuous_time), never wall time.
    let continuousSeconds: TimeInterval
}

struct MutationAuthorizationLease {
    fileprivate let authorityId: UUID
    fileprivate let generation: UUID
    let capability: MutationCapability
    let intentSha256: String
    let payloadSha256: String
    let revision: Int64
}

/// No persisted value enables mutations. Every process starts without an active
/// token, and only a fresh, successful network response can activate one.
final class MutationAuthorizationAuthority {
    static let refreshInterval: TimeInterval = 300
    private struct Active {
        let token: VerifiedMutationAuthorization
        let generation: UUID
        let acceptedAt: TimeInterval
        let deadline: TimeInterval
    }

    private let lock = NSLock()
    private let authorityId = UUID()
    private let verifier: MutationAuthorizationVerifier
    private let store: MutationAuthorizationHighWaterStoring
    private let clock: () -> MutationAuthorizationClock
    private var highWater: MutationAuthorizationHighWater?
    private var active: Active?
    private var lastAccepted: Active?
    private var highestContinuousSeconds: TimeInterval?
    private var persistenceFailed = false

    init(
        verifier: MutationAuthorizationVerifier,
        store: MutationAuthorizationHighWaterStoring,
        clock: @escaping () -> MutationAuthorizationClock
    ) throws {
        self.verifier = verifier
        self.store = store
        self.clock = clock
        highWater = try store.load()
        if let highWater, !highWater.isValid {
            throw MutationAuthorizationError.persistenceUnavailable
        }
    }

    /// Call only with a just-fetched response, never a disk/URL cache value.
    func acceptFreshResponse(_ token: String) throws {
        lock.lock()
        defer { lock.unlock() }
        do {
            guard !persistenceFailed else { throw MutationAuthorizationError.persistenceUnavailable }
            let now = try checkedClock()
            let verified = try verifier.verify(token, now: now.wallSeconds)
            if let highWater {
                guard verified.revision >= highWater.revision,
                      verified.revision != highWater.revision ||
                      verified.payloadSha256 == highWater.payloadSha256 else {
                    throw MutationAuthorizationError.rollback
                }
            }
            try persist(verified: verified, wallSeconds: now.wallSeconds)
            // Durable storage can block past expiry. Re-sample after every
            // write and never extend the deadline by time spent persisting.
            let finalNow = try checkedClock()
            guard finalNow.wallSeconds < verified.expiresAt else { throw MutationAuthorizationError.expired }
            // Repeated delivery of the same token cannot extend its monotonic
            // deadline or revive a lease invalidated by a previous refresh error.
            var deadline = now.continuousSeconds + min(900, Double(verified.expiresAt - now.wallSeconds))
            if let previous = lastAccepted, previous.token.payloadSha256 == verified.payloadSha256 {
                guard now.continuousSeconds >= previous.acceptedAt else {
                    throw MutationAuthorizationError.rollback
                }
                deadline = min(deadline, previous.deadline)
            }
            guard finalNow.continuousSeconds < deadline else { throw MutationAuthorizationError.expired }
            if let previous = active, previous.token.payloadSha256 == verified.payloadSha256 {
                active = Active(
                    token: verified,
                    generation: previous.generation,
                    acceptedAt: previous.acceptedAt,
                    deadline: min(previous.deadline, deadline)
                )
            } else {
                active = Active(
                    token: verified,
                    generation: UUID(),
                    acceptedAt: now.continuousSeconds,
                    deadline: deadline
                )
            }
            lastAccepted = active
        } catch {
            active = nil
            throw error
        }
    }

    func refreshFailed() {
        lock.lock()
        active = nil
        lock.unlock()
    }

    func isAllowed(_ capability: MutationCapability) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return (try? checkedActive(capability)) != nil
    }

    func lease(for capability: MutationCapability, intentSha256: String) throws -> MutationAuthorizationLease {
        lock.lock()
        defer { lock.unlock() }
        guard MutationAuthorizationVerifier.matches(intentSha256, "[0-9a-f]{64}") else {
            throw MutationAuthorizationError.changedIntent
        }
        let current = try checkedActive(capability)
        return MutationAuthorizationLease(
            authorityId: authorityId, generation: current.generation,
            capability: capability, intentSha256: intentSha256,
            payloadSha256: current.token.payloadSha256, revision: current.token.revision
        )
    }

    func check(_ lease: MutationAuthorizationLease, intentSha256: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try checkedLease(lease, intentSha256: intentSha256)
    }

    /// The closure must synchronously hand the already-signed bytes to transport.
    /// It must not await, acquire writer locks, prepare/sign, or call back into
    /// this authority. All frame work and writer lock waits precede this call.
    /// Refresh and revocation are serialized with the synchronous OS handoff.
    func withAuthorizedSubmission<T>(
        _ lease: MutationAuthorizationLease,
        intentSha256: String,
        enqueue: () throws -> T
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        try checkedLease(lease, intentSha256: intentSha256)
        return try enqueue()
    }

    /// Validate mutable application context after all authority waits and durable
    /// writes, then resample freshness without doing I/O. The context must not
    /// reenter policy/authority. Only the final synchronous effect runs after
    /// this last sample: native signing or transport handoff, never preparation.
    func withAuthorizedContext<T>(
        _ lease: MutationAuthorizationLease,
        intentSha256: String,
        validateContext: () throws -> Void,
        action: () throws -> T
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        for _ in 0 ..< 3 {
            try checkedLease(lease, intentSha256: intentSha256)
            try validateContext()
            do {
                try checkedLease(lease, intentSha256: intentSha256, allowPersistence: false)
                return try action()
            } catch ClockCheck.persistenceRequired {
                // Context validation crossed a wall-clock second. Persist and
                // validate the context again; never use the older context.
                continue
            }
        }
        throw MutationAuthorizationError.persistenceUnavailable
    }

    private enum ClockCheck: Error { case persistenceRequired }

    private func checkedLease(
        _ lease: MutationAuthorizationLease,
        intentSha256: String,
        allowPersistence: Bool = true
    ) throws {
        guard lease.authorityId == authorityId, lease.intentSha256 == intentSha256 else {
            throw MutationAuthorizationError.changedIntent
        }
        let current = try checkedActive(lease.capability, allowPersistence: allowPersistence)
        guard lease.generation == current.generation,
              lease.payloadSha256 == current.token.payloadSha256,
              lease.revision == current.token.revision else {
            throw MutationAuthorizationError.denied
        }
    }

    private func checkedActive(_ capability: MutationCapability, allowPersistence: Bool = true) throws -> Active {
        do {
            guard !persistenceFailed else { throw MutationAuthorizationError.persistenceUnavailable }
            let now = try checkedClock(allowPersistence: allowPersistence)
            guard let active else { throw MutationAuthorizationError.denied }
            guard now.wallSeconds < active.token.expiresAt,
                  now.continuousSeconds >= active.acceptedAt,
                  now.continuousSeconds < active.deadline else {
                self.active = nil
                throw MutationAuthorizationError.expired
            }
            guard verifier.context.compiledCapabilities.contains(capability),
                  active.token.capabilities.contains(capability) else {
                throw MutationAuthorizationError.denied
            }
            return active
        } catch {
            // Asking for a disabled capability does not revoke another allowed
            // capability; clock or storage errors do revoke the entire token.
            if !(error is ClockCheck), error as? MutationAuthorizationError != .denied { active = nil }
            throw error
        }
    }

    private func checkedClock(allowPersistence: Bool = true) throws -> MutationAuthorizationClock {
        // A bounded loop prevents slow Keychain I/O from granting from a stale
        // time sample. All callers hold the authority lock before sampling.
        for _ in 0 ..< 3 {
            let now = clock()
            guard now.wallSeconds >= 0, now.wallSeconds <= 253_402_300_799,
                  now.continuousSeconds.isFinite, now.continuousSeconds >= 0 else {
                throw MutationAuthorizationError.rollback
            }
            if let highWater, now.wallSeconds < highWater.maximumWallSeconds - 60 {
                throw MutationAuthorizationError.rollback
            }
            if let highestContinuousSeconds, now.continuousSeconds < highestContinuousSeconds {
                throw MutationAuthorizationError.rollback
            }
            highestContinuousSeconds = now.continuousSeconds
            guard let previous = highWater, now.wallSeconds > previous.maximumWallSeconds else {
                // Even an allowed small clock correction cannot revive a
                // token whose expiry was already observed and persisted.
                return MutationAuthorizationClock(
                    wallSeconds: max(now.wallSeconds, highWater?.maximumWallSeconds ?? 0),
                    continuousSeconds: now.continuousSeconds
                )
            }
            guard allowPersistence else { throw ClockCheck.persistenceRequired }
            let next = MutationAuthorizationHighWater(
                revision: previous.revision, payloadSha256: previous.payloadSha256,
                maximumWallSeconds: now.wallSeconds
            )
            do {
                try store.save(next)
                highWater = next
            } catch {
                persistenceFailed = true
                throw MutationAuthorizationError.persistenceUnavailable
            }
        }
        throw MutationAuthorizationError.persistenceUnavailable
    }

    private func persist(verified: VerifiedMutationAuthorization, wallSeconds: Int64) throws {
        let next = MutationAuthorizationHighWater(
            revision: verified.revision, payloadSha256: verified.payloadSha256,
            maximumWallSeconds: max(highWater?.maximumWallSeconds ?? 0, wallSeconds)
        )
        do {
            try store.save(next)
            highWater = next
        } catch {
            // The write may have committed before reporting an error. Reload
            // on the next process start; this process grants nothing afterward.
            persistenceFailed = true
            throw MutationAuthorizationError.persistenceUnavailable
        }
    }
}
