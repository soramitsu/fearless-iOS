import CryptoKit
import Foundation
import SSFUtils

struct IrohaConnectCryptoContext {
    let walletPublicKey: Data

    private let appKey: SymmetricKey
    private let walletKey: SymmetricKey
    private let sessionID: Data

    init(handoff: IrohaConnectWalletURI, ephemeralPrivateKey: Data? = nil) throws {
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        do {
            if let ephemeralPrivateKey {
                guard ephemeralPrivateKey.count == 32 else {
                    throw IrohaConnectError.invalidLength
                }
                privateKey = try Curve25519.KeyAgreement.PrivateKey(
                    rawRepresentation: ephemeralPrivateKey
                )
            } else {
                privateKey = Curve25519.KeyAgreement.PrivateKey()
            }

            let appPublicKey = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: handoff.appPublicKey
            )
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: appPublicKey)
            let sessionKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data("iroha:x25519:hkdf:v1".utf8),
                sharedInfo: Data("iroha:x25519:session-key".utf8),
                outputByteCount: 32
            )
            let directionSalt = try (
                Data("iroha-connect|salt|".utf8) + handoff.sessionID
            ).blake2b32()
            appKey = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: sessionKey,
                salt: directionSalt,
                info: Data("iroha-connect|k_app".utf8),
                outputByteCount: 32
            )
            walletKey = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: sessionKey,
                salt: directionSalt,
                info: Data("iroha-connect|k_wallet".utf8),
                outputByteCount: 32
            )
            walletPublicKey = privateKey.publicKey.rawRepresentation
            sessionID = handoff.sessionID
        } catch let error as IrohaConnectError {
            throw error
        } catch {
            throw IrohaConnectError.cryptographyFailed
        }
    }

    func decryptAppCiphertext(
        _ ciphertext: Data,
        sequence: UInt64
    ) throws -> Data {
        guard ciphertext.count >= 16 else {
            throw IrohaConnectError.authenticationFailed
        }
        do {
            let nonce = try ChaChaPoly.Nonce(data: nonce(sequence: sequence))
            let sealed = try ChaChaPoly.SealedBox(
                nonce: nonce,
                ciphertext: ciphertext.dropLast(16),
                tag: ciphertext.suffix(16)
            )
            return try ChaChaPoly.open(
                sealed,
                using: appKey,
                authenticating: additionalAuthenticatedData(
                    direction: .appToWallet,
                    sequence: sequence
                )
            )
        } catch {
            throw IrohaConnectError.authenticationFailed
        }
    }

    func encryptWalletPlaintext(
        _ plaintext: Data,
        sequence: UInt64
    ) throws -> Data {
        do {
            let sealed = try ChaChaPoly.seal(
                plaintext,
                using: walletKey,
                nonce: ChaChaPoly.Nonce(data: nonce(sequence: sequence)),
                authenticating: additionalAuthenticatedData(
                    direction: .walletToApp,
                    sequence: sequence
                )
            )
            return sealed.ciphertext + sealed.tag
        } catch {
            throw IrohaConnectError.cryptographyFailed
        }
    }

    private func additionalAuthenticatedData(
        direction: IrohaConnectDirection,
        sequence: UInt64
    ) -> Data {
        Data("connect:v1".utf8) +
            sessionID +
            Data([UInt8(direction.rawValue)]) +
            littleEndian(sequence) +
            Data([1])
    }

    private func nonce(sequence: UInt64) -> Data {
        Data(repeating: 0, count: 4) + littleEndian(sequence)
    }

    private func littleEndian(_ value: UInt64) -> Data {
        var encoded = value.littleEndian
        return Data(bytes: &encoded, count: MemoryLayout<UInt64>.size)
    }
}
