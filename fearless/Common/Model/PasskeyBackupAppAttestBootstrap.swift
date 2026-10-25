import CryptoKit
import DeviceCheck
import Foundation

enum PasskeyBackupAppAttestError: Error, Equatable {
    case invalidServerNonce
    case unavailable
    case ceremonyInProgress
    case cancelled
    case nativeFailure
    case invalidKeyID
    case invalidAttestation
    case serverUnavailable
    case challengeExpired
    case pendingChallengeMismatch
    case storageUnavailable
}

/// The caller must obtain this wallet-proof-bound nonce from an authenticated owner ceremony.
/// This type validates its encoding; it cannot authenticate an HTTP response by itself.
struct PasskeyBackupServerAttestationNonce: CustomStringConvertible {
    let bytes: Data
    let clientDataHash: Data

    init(base64URL: String) throws {
        guard base64URL.utf8.count == 43,
              base64URL.utf8.allSatisfy({
                  (48 ... 57).contains($0) || (65 ... 90).contains($0) ||
                      (97 ... 122).contains($0) || $0 == 45 || $0 == 95
              }),
              let decoded = Data(base64Encoded: base64URL
                  .replacingOccurrences(of: "-", with: "+")
                  .replacingOccurrences(of: "_", with: "/") + "="),
              decoded.count == 32,
              Self.base64URL(decoded) == base64URL else {
            throw PasskeyBackupAppAttestError.invalidServerNonce
        }
        bytes = decoded
        clientDataHash = Data(SHA256.hash(data: decoded))
    }

    var description: String {
        "PasskeyBackupServerAttestationNonce(<redacted>)"
    }

    static func base64URL(_ bytes: Data) -> String {
        bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Only public Apple attestation material; server verification is still mandatory.
struct PasskeyBackupAppAttestTransport: CustomStringConvertible {
    let keyId: String
    let attestationObject: String

    var kind: String {
        "app-attest"
    }

    var description: String {
        "PasskeyBackupAppAttestTransport(<redacted>)"
    }

    func serverAttestationJSON() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "kind": kind, "keyId": keyId, "attestationObject": attestationObject
        ])
    }

    init(appleKeyID: String, attestation: Data) throws {
        guard let keyBytes = Data(base64Encoded: appleKeyID), keyBytes.count == 32,
              keyBytes.base64EncodedString() == appleKeyID else {
            throw PasskeyBackupAppAttestError.invalidKeyID
        }
        guard (32 ... 32768).contains(attestation.count) else {
            throw PasskeyBackupAppAttestError.invalidAttestation
        }
        keyId = PasskeyBackupServerAttestationNonce.base64URL(keyBytes)
        attestationObject = PasskeyBackupServerAttestationNonce.base64URL(attestation)
    }
}

@MainActor
protocol PasskeyBackupAppAttestGateway: AnyObject {
    var isSupported: Bool { get }
    func generateKey(completion: @escaping (Result<String, Error>) -> Void)
    func attestKey(
        _ keyID: String, clientDataHash: Data,
        completion: @escaping (Result<Data, Error>) -> Void
    )
}

/// The DeviceCheck callback layer never forwards native errors or logs their details.
@MainActor
final class SystemPasskeyBackupAppAttestGateway: PasskeyBackupAppAttestGateway {
    private lazy var service = DCAppAttestService.shared

    var isSupported: Bool {
        service.isSupported
    }

    func generateKey(completion: @escaping (Result<String, Error>) -> Void) {
        service.generateKey { keyID, error in
            if let keyID, error == nil {
                completion(.success(keyID))
            } else {
                completion(.failure(PasskeyBackupAppAttestError.nativeFailure))
            }
        }
    }

    func attestKey(
        _ keyID: String, clientDataHash: Data,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        service.attestKey(keyID, clientDataHash: clientDataHash) { object, error in
            if let object, error == nil {
                completion(.success(object))
            } else if let error, Self.isServerUnavailable(error) {
                completion(.failure(PasskeyBackupAppAttestError.serverUnavailable))
            } else {
                completion(.failure(PasskeyBackupAppAttestError.nativeFailure))
            }
        }
    }

    nonisolated static func isServerUnavailable(_ error: Error) -> Bool {
        let native = error as NSError
        return native.domain == DCErrorDomain && native.code == DCError.Code.serverUnavailable.rawValue
    }
}

/// Disabled and unwired until the owner ceremony, app identity and device gates are qualified.
@MainActor
final class PasskeyBackupAppAttestBootstrap {
    private static var activeCeremony: UUID?

    private struct Active {
        let id: UUID
        let continuation: CheckedContinuation<PasskeyBackupAppAttestTransport, Error>
    }

    private let gateway: PasskeyBackupAppAttestGateway
    private let pendingStore: PasskeyBackupPendingAttestationStore
    private let isReleaseEnabled: Bool
    private let now: () -> Date
    private var active: Active?

    convenience init() {
        self.init(gateway: SystemPasskeyBackupAppAttestGateway())
    }

    init(
        gateway: PasskeyBackupAppAttestGateway,
        pendingStore: PasskeyBackupPendingAttestationStore? = nil,
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        now: @escaping () -> Date = Date.init
    ) {
        self.gateway = gateway
        self.pendingStore = pendingStore ?? KeychainPendingAppAttestationStore()
        self.isReleaseEnabled = isReleaseEnabled
        self.now = now
    }

    func attest(challenge: PasskeyBackupAppAttestChallenge) async throws -> PasskeyBackupAppAttestTransport {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try challenge.validate(now: now())
        guard gateway.isSupported else { throw PasskeyBackupAppAttestError.unavailable }
        try Task.checkCancellation()
        guard active == nil, Self.activeCeremony == nil else {
            throw PasskeyBackupAppAttestError.ceremonyInProgress
        }
        let pending: PasskeyBackupPendingAppAttestation?
        do { pending = try pendingStore.load() } catch {
            throw PasskeyBackupAppAttestError.storageUnavailable
        }
        if let pending, Double(pending.challenge.expiresAtSeconds) > now().timeIntervalSince1970,
           !pending.matches(challenge) {
            throw PasskeyBackupAppAttestError.pendingChallengeMismatch
        }
        if let pending, !pending.matches(challenge) {
            do { try pendingStore.clear() } catch {
                throw PasskeyBackupAppAttestError.storageUnavailable
            }
        }
        let id = UUID()
        let result: PasskeyBackupAppAttestTransport = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: PasskeyBackupAppAttestError.cancelled)
                    return
                }
                active = Active(id: id, continuation: continuation)
                Self.activeCeremony = id
                if let pending, pending.matches(challenge) {
                    attestPending(id: id, pending: pending)
                } else {
                    gateway.generateKey { [weak self] response in
                        Task { @MainActor [weak self] in
                            self?.receiveKey(id: id, result: response, challenge: challenge)
                        }
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(id: id, result: .failure(PasskeyBackupAppAttestError.cancelled))
            }
        }
        try Task.checkCancellation()
        return result
    }

    private func receiveKey(id: UUID, result: Result<String, Error>, challenge: PasskeyBackupAppAttestChallenge) {
        guard active?.id == id else { return }
        guard case let .success(appleKeyID) = result else {
            finish(id: id, result: .failure(PasskeyBackupAppAttestError.nativeFailure))
            return
        }
        do {
            let pending = try PasskeyBackupPendingAppAttestation(
                appleKeyID: appleKeyID, challenge: challenge
            )
            try pendingStore.save(pending)
            attestPending(id: id, pending: pending)
        } catch let error as PasskeyBackupAppAttestError where error == .invalidKeyID {
            finish(id: id, result: .failure(error))
        } catch {
            finish(id: id, result: .failure(PasskeyBackupAppAttestError.storageUnavailable))
        }
    }

    private func attestPending(id: UUID, pending: PasskeyBackupPendingAppAttestation) {
        gateway.attestKey(
            pending.appleKeyID, clientDataHash: pending.challenge.nonce.clientDataHash
        ) { [weak self] response in
            Task { @MainActor [weak self] in
                self?.receiveAttestation(id: id, pending: pending, result: response)
            }
        }
    }

    private func receiveAttestation(
        id: UUID, pending: PasskeyBackupPendingAppAttestation, result: Result<Data, Error>
    ) {
        guard active?.id == id else { return }
        if case let .failure(error) = result, error as? PasskeyBackupAppAttestError == .serverUnavailable {
            finish(id: id, result: .failure(PasskeyBackupAppAttestError.serverUnavailable))
            return
        }
        guard case let .success(bytes) = result else {
            do { try pendingStore.clear() } catch {
                finish(id: id, result: .failure(PasskeyBackupAppAttestError.storageUnavailable))
                return
            }
            finish(id: id, result: .failure(PasskeyBackupAppAttestError.nativeFailure))
            return
        }
        do {
            let transport = try PasskeyBackupAppAttestTransport(
                appleKeyID: pending.appleKeyID, attestation: bytes
            )
            try pendingStore.clear()
            try pending.challenge.validate(now: now())
            finish(id: id, result: .success(transport))
        } catch let error as PasskeyBackupAppAttestError where error == .challengeExpired {
            finish(id: id, result: .failure(error))
        } catch let error as PasskeyBackupAppAttestError where error == .storageUnavailable {
            finish(id: id, result: .failure(error))
        } catch {
            finish(id: id, result: .failure(PasskeyBackupAppAttestError.invalidAttestation))
        }
    }

    private func finish(id: UUID, result: Result<PasskeyBackupAppAttestTransport, Error>) {
        guard let current = active, current.id == id else { return }
        active = nil
        if Self.activeCeremony == id {
            Self.activeCeremony = nil
        }
        current.continuation.resume(with: result)
    }
}
