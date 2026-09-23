import Foundation
import SSFUtils

/// One confirmed intent, one key read, one signature, and one irreversible
/// transport handoff. No wallet material or signed bytes are retained here.
final class MutationOperationAuthorization: JSONRPCWriteAuthorizing {
    typealias Boundary = (_ action: () throws -> Void) throws -> Void
    private enum Stage { case ready, keyRead, signed, bound, handedOff, failed }
    private let stateLock = NSLock()
    private var stage = Stage.ready
    private let validateContext: () throws -> Void
    private let boundary: Boundary
    let intentSha256: String

    init(
        intentSha256: String,
        validateContext: @escaping () throws -> Void,
        boundary: @escaping Boundary
    ) throws {
        guard MutationAuthorizationVerifier.matches(intentSha256, "[0-9a-f]{64}") else {
            throw MutationAuthorizationError.changedIntent
        }
        self.intentSha256 = intentSha256
        self.validateContext = validateContext
        self.boundary = boundary
    }

    func check() throws {
        try validateContext()
        try boundary {}
    }

    func withKeyAccess<T>(_ action: () throws -> T) throws -> T {
        try perform(from: .ready, to: .keyRead, action)
    }

    /// Call only after hashing and native signer/key initialization. The action
    /// must synchronously invoke native signing, without further queued work.
    func withSignature<T>(_ action: () throws -> T) throws -> T {
        try perform(from: .keyRead, to: .signed, action)
    }

    func bindSubmission(extrinsic: Data, method: String) throws {
        guard !extrinsic.isEmpty,
              method == RPCMethod.submitExtrinsic || method == "author_submitAndWatchExtrinsic" else {
            throw MutationAuthorizationError.changedIntent
        }
        // Encoding happens in the operation factory, before final writer
        // authorization. The SDK freezes those exact parameters and this guard
        // together; no caller may reuse the guard for a different request.
        try perform(from: .signed, to: .bound) {}
    }

    func authorize(_ handoff: () throws -> Void) throws {
        try perform(from: .bound, to: .handedOff, handoff)
    }

    private func perform<T>(
        from expected: Stage,
        to next: Stage,
        _ action: () throws -> T
    ) throws -> T {
        // Context reads and all blocking application/authority lock waits must
        // precede the final authority clock sample. Never reenter policy from
        // the action passed through this boundary.
        try validateContext()
        var result: Result<T, Error>?
        try boundary {
            // Contention fails closed: no blocking wait after freshness check.
            guard self.stateLock.try() else { throw MutationAuthorizationError.denied }
            defer { self.stateLock.unlock() }
            guard result == nil, self.stage == expected else { throw MutationAuthorizationError.denied }
            self.stage = next
            do { result = .success(try action()) }
            catch {
                // A transport error after entry may mean bytes were accepted.
                // Keep handedOff so no later operation can retry this intent.
                if next != .handedOff { self.stage = .failed }
                throw error
            }
        }
        guard let result else { throw MutationAuthorizationError.denied }
        return try result.get()
    }
}

/// Length-prefixed UTF-8 prevents field-boundary ambiguity in confirmed intents.
/// The capability, chain/account identity, route/call inputs and quoted amounts
/// are provided by the feature authorizer, never by remote configuration.
enum MutationIntentDigest {
    static func make(_ fields: [String]) throws -> String {
        guard !fields.isEmpty, fields.count <= 64 else { throw MutationAuthorizationError.changedIntent }
        var bytes = Data("FearlessWallet-MutationIntent-v1\n".utf8)
        for field in fields {
            let value = Data(field.utf8)
            guard value.count <= 16384 else { throw MutationAuthorizationError.changedIntent }
            var size = UInt32(value.count).bigEndian
            withUnsafeBytes(of: &size) { bytes.append(contentsOf: $0) }
            bytes.append(value)
        }
        return MutationAuthorizationVerifier.sha256(bytes)
    }
}
