import CryptoKit
import Foundation

@MainActor
protocol PasskeyBackupFirstOwnerAppAttestor {
    func attest(challenge: PasskeyBackupAppAttestChallenge) async throws -> PasskeyBackupAppAttestTransport
}

extension PasskeyBackupAppAttestBootstrap: PasskeyBackupFirstOwnerAppAttestor {}

/// Candidate first-owner path. The compiled release gate is false and no app flow
/// constructs this source. A returned session only authorizes the next encrypted
/// generation operation; it never means a recoverable backup exists. The separate
/// native PRF registration adapter is unwired, and a concrete original-wallet
/// signer and real-provider qualification remain missing.
@MainActor
final class HTTPPasskeyOwnerBootstrapSource {
    private static let challengePath = "/api/passkey-backup/v1/owner/bootstrap/challenge"
    private static let completePath = "/api/passkey-backup/v1/owner/bootstrap/complete"
    private static let beginBody = Data(#"{"schemaVersion":1,"platform":"ios"}"#.utf8)
    private static let maximumChallengeBytes = 8192
    private static let maximumCompleteBytes = 8192
    private static let maximumRequestBytes = 128 * 1024

    private let challengeURL: URL
    private let completeURL: URL
    private let transport: PasskeyBackupHTTPTransport
    private let isReleaseEnabled: Bool
    private let nowUnixSeconds: () -> Int64

    init(
        baseURL: URL, transport: PasskeyBackupHTTPTransport,
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        nowUnixSeconds: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) }
    ) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https", let host = components.host, !host.isEmpty,
              host == host.lowercased(), components.user == nil, components.password == nil,
              components.port == nil, components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/",
              baseURL.absoluteString == "https://\(host)" || baseURL.absoluteString == "https://\(host)/",
              let challengeURL = URL(string: "https://\(host)\(Self.challengePath)"),
              let completeURL = URL(string: "https://\(host)\(Self.completePath)") else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidEndpoint
        }
        self.challengeURL = challengeURL
        self.completeURL = completeURL
        self.transport = transport
        self.isReleaseEnabled = isReleaseEnabled
        self.nowUnixSeconds = nowUnixSeconds
    }

    @available(iOS 15.0, macOS 12.0, *)
    convenience init(baseURL: URL = PasskeyBackupReleaseConfig.challengeServiceBaseURL) throws {
        try self.init(
            baseURL: baseURL,
            transport: URLSessionPasskeyBackupHTTPTransport(maximumResponseBytes: Self.maximumChallengeBytes)
        )
    }

    func begin() async throws -> PasskeyBackupFirstOwnerChallenge {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try Task.checkCancellation()
        let response = try await post(url: challengeURL, body: Self.beginBody)
        guard response.body.count <= Self.maximumChallengeBytes else {
            throw PasskeyBackupFirstOwnerBootstrapError.responseTooLarge
        }
        guard response.statusCode == 200 else {
            throw PasskeyBackupFirstOwnerBootstrapError.httpStatus(response.statusCode)
        }
        return try decodeChallenge(response.body)
    }

    private func decodeChallenge(_ body: Data) throws -> PasskeyBackupFirstOwnerChallenge {
        do {
            let object = try PasskeyBackupOwnerResponseJSON.parseObject(body)
            guard Set(object.keys) == Set([
                "ceremonyId", "kind", "challenge", "rpId", "platform",
                "subject", "namespace", "userHandle", "expiresAt"
            ]),
                object["kind"] == .string("bootstrap"),
                object["rpId"] == .string(PasskeyBackupContract.PASSKEY_RP_ID),
                object["platform"] == .string("ios"),
                case let .string(ceremonyID) = object["ceremonyId"],
                case let .string(encodedChallenge) = object["challenge"],
                case let .string(subject) = object["subject"],
                case let .string(namespace) = object["namespace"],
                case let .string(encodedHandle) = object["userHandle"],
                case let .number(expiresAt) = object["expiresAt"] else {
                throw PasskeyBackupFirstOwnerBootstrapError.malformedChallenge
            }
            let challenge = try PasskeyBackupFirstOwnerChallenge(
                ceremonyID: ceremonyID,
                challenge: PasskeyBackupContract.decodeBase64URL(encodedChallenge),
                ownerSubject: subject, backupNamespace: namespace,
                userHandle: PasskeyBackupContract.decodeBase64URL(encodedHandle),
                expiresAtUnixSeconds: expiresAt
            )
            try challenge.requireFresh(nowUnixSeconds: nowUnixSeconds())
            return challenge
        } catch let error as PasskeyBackupFirstOwnerBootstrapError {
            throw error
        } catch {
            throw PasskeyBackupFirstOwnerBootstrapError.malformedChallenge
        }
    }

    /// The signer must be backed by an application-owned, locally authorized
    /// original wallet key. No wallet secret or PRF output enters this request.
    func complete(
        challenge: PasskeyBackupFirstOwnerChallenge,
        registration: PasskeyFirstOwnerRegistration,
        expectedIdentity: PasskeyBackupExpectedWalletIdentity,
        signer: PasskeyOwnerWalletSigner,
        attestor: PasskeyBackupFirstOwnerAppAttestor
    ) async throws -> PasskeyBackupOwnerSession {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try challenge.requireFresh(nowUnixSeconds: nowUnixSeconds())
        try Task.checkCancellation()
        let message = try PasskeyBackupFirstOwnerProofFormat.walletMessage(
            challenge: challenge, registration: registration
        )
        let signed = try await signer.authorizeAndSign(message, expectedIdentity: expectedIdentity)
        let proof = signed.proof
        try signed.evidence.requireMatch(expectedIdentity, proof: proof)
        if proof.scheme == .ed25519 {
            guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: proof.publicKey),
                  publicKey.isValidSignature(proof.signature, for: message) else {
                throw PasskeyBackupFirstOwnerBootstrapError.invalidWalletProof
            }
        }
        try Task.checkCancellation()
        try challenge.requireFresh(nowUnixSeconds: nowUnixSeconds())
        let nonce = PasskeyBackupFirstOwnerProofFormat.appAttestationNonce(message: message, proof: proof)
        let attestationChallenge = try PasskeyBackupAppAttestChallenge(
            serverNonce: nonce, ceremonyID: challenge.ceremonyID,
            subject: challenge.ownerSubject,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(challenge.expiresAtUnixSeconds))
        )
        let attestation = try await attestor.attest(challenge: attestationChallenge)
        try Task.checkCancellation()
        try challenge.requireFresh(nowUnixSeconds: nowUnixSeconds())
        let currentWallet = try await signer.verifyCurrentWallet(expectedIdentity: expectedIdentity)
        try currentWallet.requireMatch(expectedIdentity, proof: proof)
        try Task.checkCancellation()
        try challenge.requireFresh(nowUnixSeconds: nowUnixSeconds())

        let body = try completeBody(
            challenge: challenge, registration: registration, proof: proof, attestation: attestation
        )
        // Any response failure after dispatch can race a committed owner.
        // Never issue a new bootstrap ceremony as automatic compensation.
        do {
            let response = try await post(url: completeURL, body: body)
            guard response.body.count <= Self.maximumCompleteBytes,
                  response.statusCode == 200 else {
                throw PasskeyBackupFirstOwnerBootstrapError.completionOutcomeUnknown
            }
            return try decodeSession(response.body, challenge: challenge)
        } catch {
            // The one-use ceremony may have committed before a connection failed.
            // Authenticate the new credential to reconcile; do not re-enroll.
            throw PasskeyBackupFirstOwnerBootstrapError.completionOutcomeUnknown
        }
    }

    private func completeBody(
        challenge: PasskeyBackupFirstOwnerChallenge,
        registration: PasskeyFirstOwnerRegistration,
        proof: PasskeyBackupFirstOwnerWalletProof,
        attestation: PasskeyBackupAppAttestTransport
    ) throws -> Data {
        let request: [String: Any] = try [
            "schemaVersion": 1, "ceremonyId": challenge.ceremonyID,
            "credential": registration.credentialObject(),
            "walletProof": proof.publicObject(),
            "appAttestation": JSONSerialization.jsonObject(with: attestation.serverAttestationJSON())
        ]
        guard JSONSerialization.isValidJSONObject(request) else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidRegistration
        }
        let body = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        guard body.count <= Self.maximumRequestBytes else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidRegistration
        }
        return body
    }

    private func decodeSession(
        _ body: Data, challenge: PasskeyBackupFirstOwnerChallenge
    ) throws -> PasskeyBackupOwnerSession {
        do {
            let object = try PasskeyBackupOwnerResponseJSON.parseObject(body)
            guard Set(object.keys) == Set([
                "sessionToken", "subject", "namespace", "generation", "platform", "expiresAt"
            ]),
                object["platform"] == .string("ios"),
                case let .string(token) = object["sessionToken"],
                case let .string(subject) = object["subject"],
                case let .string(namespace) = object["namespace"],
                case let .number(generation) = object["generation"],
                case let .number(expiresAt) = object["expiresAt"],
                generation == 0, subject == challenge.ownerSubject,
                namespace == challenge.backupNamespace else {
                throw PasskeyBackupFirstOwnerBootstrapError.malformedSession
            }
            let session = try PasskeyBackupOwnerSession(
                token: token, ownerSubject: subject, backupNamespace: namespace,
                generation: generation, platform: "ios", expiresAtUnixSeconds: expiresAt
            )
            try session.requireFresh(nowUnixSeconds: nowUnixSeconds())
            return session
        } catch {
            throw PasskeyBackupFirstOwnerBootstrapError.malformedSession
        }
    }

    private func post(url: URL, body: Data) async throws -> PasskeyBackupHTTPResponse {
        try Task.checkCancellation()
        let response = try await transport.execute(PasskeyBackupHTTPRequest(
            method: "POST", url: url,
            headers: ["Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store"],
            body: body
        ))
        try Task.checkCancellation()
        return response
    }
}
