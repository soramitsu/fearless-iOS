import CryptoKit
import Foundation

enum PasskeyBackupFirstOwnerBootstrapError: Error, Equatable {
    case invalidEndpoint
    case malformedChallenge
    case expiredChallenge
    case invalidRegistration
    case invalidWalletProof
    case malformedSession
    case responseTooLarge
    case httpStatus(Int)
    case completionOutcomeUnknown
}

/// An untrusted, short-lived owner namespace returned by the authority. It has no
/// wallet authority until the original wallet signs its exact registration bytes.
struct PasskeyBackupFirstOwnerChallenge: CustomStringConvertible, CustomReflectable {
    let ceremonyID: String
    let challenge: Data
    let ownerSubject: String
    let backupNamespace: String
    let userHandle: Data
    let expiresAtUnixSeconds: Int64

    init(
        ceremonyID: String, challenge: Data, ownerSubject: String,
        backupNamespace: String, userHandle: Data, expiresAtUnixSeconds: Int64
    ) throws {
        guard Self.opaque(ceremonyID, prefix: "ceremony."),
              Self.opaque(ownerSubject, prefix: "owner:"),
              Self.opaque(backupNamespace, prefix: "backup:"),
              challenge.count == 32, userHandle.count == 32,
              expiresAtUnixSeconds > 0 else {
            throw PasskeyBackupFirstOwnerBootstrapError.malformedChallenge
        }
        self.ceremonyID = ceremonyID
        self.challenge = challenge
        self.ownerSubject = ownerSubject
        self.backupNamespace = backupNamespace
        self.userHandle = userHandle
        self.expiresAtUnixSeconds = expiresAtUnixSeconds
    }

    func requireFresh(nowUnixSeconds: Int64) throws {
        guard nowUnixSeconds >= 0, nowUnixSeconds <= Int64.max - 300,
              expiresAtUnixSeconds > nowUnixSeconds,
              expiresAtUnixSeconds <= nowUnixSeconds + 300 else {
            throw PasskeyBackupFirstOwnerBootstrapError.expiredChallenge
        }
    }

    var description: String {
        "PasskeyBackupFirstOwnerChallenge(<redacted>)"
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }

    private static func opaque(_ value: String, prefix: String) -> Bool {
        guard value.hasPrefix(prefix),
              let bytes = try? PasskeyBackupContract.decodeBase64URL(String(value.dropFirst(prefix.count))) else {
            return false
        }
        return bytes.count == 32
    }
}

/// Constructed from the native registration's *public* WebAuthn fields. It
/// deliberately has no PRF property or initializer that accepts local PRF bytes.
struct PasskeyFirstOwnerRegistration: CustomStringConvertible, CustomReflectable {
    let credentialID: Data
    let clientDataJSON: Data
    let attestationObject: Data

    init(credentialID: Data, clientDataJSON: Data, attestationObject: Data) throws {
        guard (1 ... 384).contains(credentialID.count),
              (1 ... 8192).contains(clientDataJSON.count),
              (1 ... 16384).contains(attestationObject.count) else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidRegistration
        }
        _ = try PasskeyCredentialResponseSerializer.registrationJSON(
            credentialID: credentialID, clientDataJSON: clientDataJSON,
            attestationObject: attestationObject
        )
        self.credentialID = credentialID
        self.clientDataJSON = clientDataJSON
        self.attestationObject = attestationObject
    }

    func validate(against challenge: PasskeyBackupFirstOwnerChallenge) throws {
        guard let clientData = try? JSONSerialization.jsonObject(with: clientDataJSON) as? [String: Any],
              clientData["type"] as? String == "webauthn.create",
              clientData["challenge"] as? String == Self.base64URL(challenge.challenge),
              clientData["origin"] as? String == "https://fearlesswallet.io",
              clientData["crossOrigin"] as? Bool != true else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidRegistration
        }
    }

    func credentialObject() throws -> [String: Any] {
        let json = try PasskeyCredentialResponseSerializer.registrationJSON(
            credentialID: credentialID, clientDataJSON: clientDataJSON,
            attestationObject: attestationObject
        )
        guard let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidRegistration
        }
        return object
    }

    /// Matches the server's JSON.stringify positional registration commitment.
    func commitmentSHA256() throws -> Data {
        let credential = try credentialObject()
        guard let response = credential["response"] as? [String: Any],
              let id = credential["id"] as? String,
              let rawID = credential["rawId"] as? String,
              let type = credential["type"] as? String,
              let attachment = credential["authenticatorAttachment"] as? String,
              let clientData = response["clientDataJSON"] as? String,
              let attestation = response["attestationObject"] as? String else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidRegistration
        }
        let positional: [Any] = [
            id, rawID, type, attachment, NSNull(), clientData, attestation,
            NSNull(), NSNull(), NSNull(), NSNull()
        ]
        let bytes = try JSONSerialization.data(withJSONObject: positional, options: [.fragmentsAllowed])
        return Data(SHA256.hash(data: bytes))
    }

    var description: String {
        "PasskeyFirstOwnerRegistration(<redacted>)"
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }

    private static func base64URL(_ bytes: Data) -> String {
        PasskeyBackupServerAttestationNonce.base64URL(bytes)
    }
}

/// Only an application-owned implementation may unlock the original wallet and
/// sign the server/credential-bound message. It must recheck the actual selected
/// wallet after UI and async App Attest, including original-key decryption, signing and export.
/// The bootstrap client never handles keys.
@MainActor
protocol PasskeyOwnerWalletSigner {
    func authorizeAndSign(
        _ message: Data, expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyOwnerWalletSignedProof

    func verifyCurrentWallet(
        expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyOwnerWalletEvidence
}

struct PasskeyOwnerWalletEvidence: CustomStringConvertible, CustomReflectable {
    let observedIdentity: PasskeyBackupExpectedWalletIdentity
    let authorizedScheme: PasskeyBackupFirstOwnerWalletProof.Scheme
    let authorizedPublicKey: Data
    let decryptionVerified: Bool
    let originalKeySigningVerified: Bool
    let originalKeyExportVerified: Bool

    func requireMatch(
        _ expected: PasskeyBackupExpectedWalletIdentity,
        proof: PasskeyBackupFirstOwnerWalletProof
    ) throws {
        guard observedIdentity.storageKey == expected.storageKey,
              observedIdentity.walletId == expected.walletId,
              observedIdentity.publicIdentitySha256 == expected.publicIdentitySha256,
              authorizedScheme == proof.scheme,
              authorizedPublicKey == proof.normalizedPublicKey,
              decryptionVerified, originalKeySigningVerified, originalKeyExportVerified else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidWalletProof
        }
    }

    var description: String {
        "PasskeyOwnerWalletEvidence(<redacted>)"
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

struct PasskeyOwnerWalletSignedProof: CustomStringConvertible, CustomReflectable {
    let proof: PasskeyBackupFirstOwnerWalletProof
    let evidence: PasskeyOwnerWalletEvidence

    var description: String {
        "PasskeyOwnerWalletSignedProof(<redacted>)"
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

struct PasskeyBackupFirstOwnerWalletProof: CustomStringConvertible, CustomReflectable {
    enum Scheme: String { case ed25519, secp256k1 }

    let scheme: Scheme
    let publicKey: Data
    let signature: Data

    init(scheme: Scheme, publicKey: Data, signature: Data) throws {
        guard signature.count == 64,
              (scheme == .ed25519 && publicKey.count == 32) ||
              (scheme == .secp256k1 && (publicKey.count == 33 || publicKey.count == 65)) else {
            throw PasskeyBackupFirstOwnerBootstrapError.invalidWalletProof
        }
        if scheme == .secp256k1 {
            guard (publicKey.count == 33 && (publicKey[0] == 2 || publicKey[0] == 3)) ||
                (publicKey.count == 65 && publicKey[0] == 4) else {
                throw PasskeyBackupFirstOwnerBootstrapError.invalidWalletProof
            }
        }
        self.scheme = scheme
        self.publicKey = publicKey
        self.signature = signature
    }

    var normalizedPublicKey: Data {
        guard scheme == .secp256k1, publicKey.count == 65 else { return publicKey }
        return Data([publicKey[64] & 1 == 0 ? 2 : 3]) + publicKey.subdata(in: 1 ..< 33)
    }

    func publicObject() -> [String: String] {
        ["scheme": scheme.rawValue,
         "publicKey": PasskeyBackupServerAttestationNonce.base64URL(publicKey),
         "signature": PasskeyBackupServerAttestationNonce.base64URL(signature)]
    }

    var description: String {
        "PasskeyBackupFirstOwnerWalletProof(<redacted>)"
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

enum PasskeyBackupFirstOwnerProofFormat {
    static func walletMessage(
        challenge: PasskeyBackupFirstOwnerChallenge,
        registration: PasskeyFirstOwnerRegistration
    ) throws -> Data {
        try registration.validate(against: challenge)
        var message = Data("FP_OWNER_BOOTSTRAP_WALLET_V1\0".utf8)
        for field in try [
            Data(challenge.ceremonyID.utf8), challenge.challenge,
            Data(PasskeyBackupContract.PASSKEY_RP_ID.utf8), Data("ios".utf8),
            Data(challenge.ownerSubject.utf8), Data(challenge.backupNamespace.utf8),
            challenge.userHandle, registration.commitmentSHA256()
        ] {
            appendField(field, to: &message)
        }
        return message
    }

    static func appAttestationNonce(message: Data, proof: PasskeyBackupFirstOwnerWalletProof) -> String {
        var bytes = Data("FP_OWNER_BOOTSTRAP_APP_V1\0".utf8)
        for field in [message, Data(proof.scheme.rawValue.utf8), proof.normalizedPublicKey, proof.signature] {
            appendField(field, to: &bytes)
        }
        return PasskeyBackupServerAttestationNonce.base64URL(Data(SHA256.hash(data: bytes)))
    }

    private static func appendField(_ field: Data, to result: inout Data) {
        var length = UInt32(field.count).bigEndian
        withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
        result.append(field)
    }
}
