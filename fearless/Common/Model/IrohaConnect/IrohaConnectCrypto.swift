import CryptoKit
import Foundation
import SSFUtils

/// The wallet's ephemeral X25519 session key pair.
struct IrohaConnectWalletKeyPair {
    let privateKey: Curve25519.KeyAgreement.PrivateKey

    var publicKey: Data {
        privateKey.publicKey.rawRepresentation
    }

    init(privateKey: Curve25519.KeyAgreement.PrivateKey = Curve25519.KeyAgreement.PrivateKey()) {
        self.privateKey = privateKey
    }

    init(rawPrivateKey: Data) throws {
        guard rawPrivateKey.count == 32 else {
            throw IrohaConnectError.invalidFrame("the wallet session key must be 32 bytes")
        }
        do {
            privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawPrivateKey)
        } catch {
            throw IrohaConnectError.invalidFrame("the wallet session key is invalid")
        }
    }
}

/// Direction-separated ChaCha20-Poly1305 keys: X25519 -> HKDF-SHA256 session key -> HKDF per direction.
struct IrohaConnectDirectionKeys {
    private static let tagBytes = 16

    let appKey: SymmetricKey
    let walletKey: SymmetricKey

    init(walletKeyPair: IrohaConnectWalletKeyPair, appPublicKey: Data, sessionID: Data) throws {
        do {
            let appKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: appPublicKey)
            let shared = try walletKeyPair.privateKey.sharedSecretFromKeyAgreement(with: appKey)
            let sessionKey = shared.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data("iroha:x25519:hkdf:v1".utf8),
                sharedInfo: Data("iroha:x25519:session-key".utf8),
                outputByteCount: 32
            )
            let salt = try (Data("iroha-connect|salt|".utf8) + sessionID).blake2b32()
            self.appKey = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: sessionKey,
                salt: salt,
                info: Data("iroha-connect|k_app".utf8),
                outputByteCount: 32
            )
            walletKey = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: sessionKey,
                salt: salt,
                info: Data("iroha-connect|k_wallet".utf8),
                outputByteCount: 32
            )
        } catch {
            throw IrohaConnectError.invalidFrame("the session keys could not be derived")
        }
    }

    func openApp(_ aead: Data, sessionID: Data, sequence: UInt64) -> Data? {
        guard aead.count >= Self.tagBytes else {
            return nil
        }
        do {
            let box = try ChaChaPoly.SealedBox(
                nonce: ChaChaPoly.Nonce(data: Self.nonce(sequence)),
                ciphertext: aead.dropLast(Self.tagBytes),
                tag: aead.suffix(Self.tagBytes)
            )
            return try ChaChaPoly.open(
                box,
                using: appKey,
                authenticating: Self.additionalData(sessionID: sessionID, direction: .appToWallet, sequence: sequence)
            )
        } catch {
            return nil
        }
    }

    func sealWallet(_ plaintext: Data, sessionID: Data, sequence: UInt64) -> Data? {
        do {
            let box = try ChaChaPoly.seal(
                plaintext,
                using: walletKey,
                nonce: ChaChaPoly.Nonce(data: Self.nonce(sequence)),
                authenticating: Self.additionalData(sessionID: sessionID, direction: .walletToApp, sequence: sequence)
            )
            return box.ciphertext + box.tag
        } catch {
            return nil
        }
    }

    static func nonce(_ sequence: UInt64) -> Data {
        Data(count: 4) + IrohaConnectNorito.u64(sequence)
    }

    static func additionalData(sessionID: Data, direction: IrohaConnectDirection, sequence: UInt64) -> Data {
        Data("connect:v1".utf8) + sessionID + Data([UInt8(direction.rawValue)]) + IrohaConnectNorito.u64(sequence) + Data([1])
    }
}
