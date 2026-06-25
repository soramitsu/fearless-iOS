import CryptoKit
import Foundation

enum SolanaSignerError: Error, Equatable {
    case emptyMessage
    case messageTooLarge
    case invalidPrivateKeyLength
    case invalidPublicKeyLength
    case invalidSignatureLength
}

struct SolanaSignature: Equatable {
    let derivationPath: String
    let address: String
    let publicKey: Data
    let message: Data
    let signature: Data
    let signatureBase58: String
    let signatureHex: String
}

enum SolanaSigner {
    private static let privateKeyLength = 32
    private static let publicKeyLength = 32
    private static let signatureLength = 64
    private static let maxMessageLength = 64 * 1024
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    static func signMessage(
        mnemonic: String,
        message: Data,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault
    ) throws -> SolanaSignature {
        let account = try SolanaKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            passphrase: passphrase,
            derivationPath: derivationPath
        )
        let signature = try signMessage(privateKey: account.privateKey, message: message)

        return SolanaSignature(
            derivationPath: account.derivationPath,
            address: account.address,
            publicKey: account.publicKey,
            message: message,
            signature: signature,
            signatureBase58: base58Encode(Array(signature)),
            signatureHex: signature.hexString
        )
    }

    static func signMessage(privateKey: Data, message: Data) throws -> Data {
        guard privateKey.count == privateKeyLength else {
            throw SolanaSignerError.invalidPrivateKeyLength
        }

        try validateMessage(message)

        return try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            .signature(for: message)
    }

    static func verifyMessage(publicKey: Data, message: Data, signature: Data) throws -> Bool {
        guard publicKey.count == publicKeyLength else {
            throw SolanaSignerError.invalidPublicKeyLength
        }

        guard signature.count == signatureLength else {
            throw SolanaSignerError.invalidSignatureLength
        }

        try validateMessage(message)

        return try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
            .isValidSignature(signature, for: message)
    }

    private static func validateMessage(_ message: Data) throws {
        guard !message.isEmpty else {
            throw SolanaSignerError.emptyMessage
        }

        guard message.count <= maxMessageLength else {
            throw SolanaSignerError.messageTooLarge
        }
    }

    private static func base58Encode(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else {
            return ""
        }

        var digits: [Int] = []

        for byte in bytes {
            var carry = Int(byte)

            for index in digits.indices {
                let value = digits[index] * 256 + carry
                digits[index] = value % base58Alphabet.count
                carry = value / base58Alphabet.count
            }

            while carry > 0 {
                digits.append(carry % base58Alphabet.count)
                carry /= base58Alphabet.count
            }
        }

        var result = String(repeating: String(base58Alphabet[0]), count: bytes.prefix { $0 == 0 }.count)
        for digit in digits.reversed() {
            result.append(base58Alphabet[digit])
        }

        return result
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
