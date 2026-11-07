import CryptoKit
import Foundation
import Security

public enum WalletConnectCryptoError: Error, Equatable {
    case invalidKey
    case lowOrderPoint
    case invalidEnvelope
    case unsupportedEnvelopeType(UInt8)
    case unexpectedEnvelopeType(UInt8)
    case authenticationFailed
    case randomGenerationFailed
}

/// WalletConnect v2 cryptography on CryptoKit: X25519 key agreement, HKDF-SHA256 session keys, SHA-256 topics and
/// ChaCha20-Poly1305 envelopes.
enum WalletConnectCrypto {
    static let keyLength = 32
    static let nonceLength = 12
    static let tagLength = 16

    /// Type 0 envelopes carry a message under a key both peers already have.
    static let envelopeType0: UInt8 = 0
    /// Type 1 envelopes also carry the sender's public key. Sign sessions never need them; they are read, not opened.
    static let envelopeType1: UInt8 = 1

    static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw WalletConnectCryptoError.randomGenerationFailed
        }
        return Data(bytes)
    }

    /// 32 random bytes: a pairing's symmetric key, or a relay sign-in token's subject.
    static func randomKey() throws -> Data {
        try randomBytes(keyLength)
    }

    /// The key two peers share: X25519, then HKDF-SHA256 with no salt and no info, 32 bytes.
    static func deriveSymmetricKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Data
    ) throws -> Data {
        guard peerPublicKey.count == keyLength else {
            throw WalletConnectCryptoError.invalidKey
        }
        let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let shared = try privateKey.sharedSecretFromKeyAgreement(with: peer)

        // A low-order peer key gives the all-zero secret, which an attacker would know too.
        let isZero = shared.withUnsafeBytes { buffer in buffer.allSatisfy { $0 == 0 } }
        guard !isZero else {
            throw WalletConnectCryptoError.lowOrderPoint
        }

        let key = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: keyLength
        )
        return key.withUnsafeBytes { Data($0) }
    }

    /// A symmetric key's topic: its SHA-256, in hex.
    static func topic(forSymmetricKey key: Data) -> String {
        Hex.encode(Data(SHA256.hash(data: key)))
    }

    /// The SHA-256 of a relay message as sent. It names the message for deduplication and for the Verify service.
    static func messageHash(_ message: String) -> String {
        Hex.encode(Data(SHA256.hash(data: Data(message.utf8))))
    }

    /// Seals a message in a type 0 envelope: `0x00 | nonce(12) | ciphertext | tag(16)`, base64 with padding.
    static func seal(_ plaintext: Data, symmetricKey: Data, nonce: Data? = nil) throws -> String {
        guard symmetricKey.count == keyLength else {
            throw WalletConnectCryptoError.invalidKey
        }
        let nonceBytes = try nonce ?? randomBytes(nonceLength)
        let box = try ChaChaPoly.seal(
            plaintext,
            using: SymmetricKey(data: symmetricKey),
            nonce: ChaChaPoly.Nonce(data: nonceBytes)
        )
        var envelope = Data([envelopeType0])
        envelope.append(box.nonce.withUnsafeBytes { Data($0) })
        envelope.append(box.ciphertext)
        envelope.append(box.tag)
        return Base64.encode(envelope)
    }

    struct Envelope: Equatable {
        let type: UInt8
        let senderPublicKey: Data?
        let nonce: Data
        let sealed: Data
    }

    static func decodeEnvelope(_ encoded: String) throws -> Envelope {
        guard let bytes = Base64.decode(encoded), let type = bytes.first else {
            throw WalletConnectCryptoError.invalidEnvelope
        }
        let body = bytes.dropFirst()

        switch type {
        case envelopeType0:
            guard body.count >= nonceLength + tagLength else {
                throw WalletConnectCryptoError.invalidEnvelope
            }
            return Envelope(
                type: type,
                senderPublicKey: nil,
                nonce: Data(body.prefix(nonceLength)),
                sealed: Data(body.dropFirst(nonceLength))
            )
        case envelopeType1:
            guard body.count >= keyLength + nonceLength + tagLength else {
                throw WalletConnectCryptoError.invalidEnvelope
            }
            return Envelope(
                type: type,
                senderPublicKey: Data(body.prefix(keyLength)),
                nonce: Data(body.dropFirst(keyLength).prefix(nonceLength)),
                sealed: Data(body.dropFirst(keyLength + nonceLength))
            )
        default:
            throw WalletConnectCryptoError.unsupportedEnvelopeType(type)
        }
    }

    /// Opens a type 0 envelope. A changed byte or another key fails authentication.
    static func open(_ encoded: String, symmetricKey: Data) throws -> Data {
        guard symmetricKey.count == keyLength else {
            throw WalletConnectCryptoError.invalidKey
        }
        let envelope = try decodeEnvelope(encoded)
        guard envelope.type == envelopeType0 else {
            throw WalletConnectCryptoError.unexpectedEnvelopeType(envelope.type)
        }
        do {
            let box = try ChaChaPoly.SealedBox(
                nonce: ChaChaPoly.Nonce(data: envelope.nonce),
                ciphertext: envelope.sealed.dropLast(tagLength),
                tag: envelope.sealed.suffix(tagLength)
            )
            return try ChaChaPoly.open(box, using: SymmetricKey(data: symmetricKey))
        } catch {
            throw WalletConnectCryptoError.authenticationFailed
        }
    }
}
