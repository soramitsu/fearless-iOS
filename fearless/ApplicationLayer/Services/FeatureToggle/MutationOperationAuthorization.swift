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
    /// The call bytes the confirmed intent names, when it names them. The operation factory encodes the call again
    /// after authorization, with whatever runtime coder exists then, so the signed extrinsic must carry these bytes.
    private let expectedCall: Data?
    let intentSha256: String

    init(
        intentSha256: String,
        expectedCall: Data? = nil,
        validateContext: @escaping () throws -> Void,
        boundary: @escaping Boundary
    ) throws {
        guard MutationAuthorizationVerifier.matches(intentSha256, "[0-9a-f]{64}"),
              expectedCall?.isEmpty != true else {
            throw MutationAuthorizationError.changedIntent
        }
        self.intentSha256 = intentSha256
        self.expectedCall = expectedCall
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
        try perform(from: .signed, to: .bound) {
            // A mismatch consumes the operation: nothing it signed can be sent.
            if let expectedCall, !Self.extrinsic(extrinsic, endsWithCall: expectedCall) {
                throw MutationAuthorizationError.changedIntent
            }
        }
    }

    /// A signed extrinsic is `compact(length) ++ version ++ address ++ signature ++ extra ++ call`, so the call is its
    /// final component. True when the length prefix covers exactly the bytes after it and those end with `call`.
    static func extrinsic(_ extrinsic: Data, endsWithCall call: Data) -> Bool {
        let bytes = [UInt8](extrinsic)
        guard !call.isEmpty, let first = bytes.first else { return false }
        let length: Int
        let prefixSize: Int
        switch first & 0b11 {
        case 0:
            (length, prefixSize) = (Int(first >> 2), 1)
        case 1 where bytes.count >= 2:
            (length, prefixSize) = (Int(UInt16(bytes[0]) | UInt16(bytes[1]) << 8) >> 2, 2)
        case 2 where bytes.count >= 4:
            let value = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            (length, prefixSize) = (Int(value >> 2), 4)
        default:
            return false
        }
        return length == bytes.count - prefixSize && length > call.count && bytes.suffix(call.count).elementsEqual(call)
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
