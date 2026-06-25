import CommonCrypto
import CryptoKit
import Foundation

enum SolanaKeyDerivationError: Error, Equatable {
    case emptyMnemonic
    case emptySeed
    case invalidDerivationPath
    case nonHardenedDerivationComponent
    case invalidDerivationIndex
    case invalidPrivateKeyLength
    case invalidPublicKeyLength
    case keyDerivationFailed
}

struct SolanaAccount: Equatable {
    let derivationPath: String
    let privateKey: Data
    let chainCode: Data
    let publicKey: Data
    let address: String
}

struct SolanaDerivedPrivateKey: Equatable {
    let privateKey: Data
    let chainCode: Data
}

enum SolanaKeyDerivation {
    private static let ed25519SeedKey = Data("ed25519 seed".utf8)
    private static let hardenedOffset: Int64 = 0x8000_0000
    private static let maxChildIndex: Int64 = 0x7FFF_FFFF
    private static let privateKeyLength = 32
    private static let publicKeyLength = 32
    private static let bip39Rounds = 2048
    private static let bip39SeedLength = 64
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    static func deriveAccount(
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault
    ) throws -> SolanaAccount {
        let normalizedMnemonic = try normalizeMnemonic(mnemonic)
        let seed = try bip39Seed(mnemonic: normalizedMnemonic, passphrase: passphrase)
        let derivedKey = try derivePrivateKey(seed: seed, derivationPath: derivationPath)
        let publicKey = try publicKey(fromPrivateKey: derivedKey.privateKey)

        return SolanaAccount(
            derivationPath: derivationPath,
            privateKey: derivedKey.privateKey,
            chainCode: derivedKey.chainCode,
            publicKey: publicKey,
            address: try address(fromPublicKey: publicKey)
        )
    }

    static func derivePrivateKey(
        seed: Data,
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault
    ) throws -> SolanaDerivedPrivateKey {
        guard !seed.isEmpty else {
            throw SolanaKeyDerivationError.emptySeed
        }

        let nodes = try parseHardenedDerivationPath(derivationPath)
        var digest = hmacSha512(key: ed25519SeedKey, data: seed)
        var privateKey = digest.prefix(privateKeyLength)
        var chainCode = digest.suffix(privateKeyLength)

        for index in nodes {
            var data = Data([0])
            data.append(privateKey)

            var hardenedIndex = UInt32(index + hardenedOffset).bigEndian
            withUnsafeBytes(of: &hardenedIndex) { data.append(contentsOf: $0) }

            digest = hmacSha512(key: chainCode, data: data)
            privateKey = digest.prefix(privateKeyLength)
            chainCode = digest.suffix(privateKeyLength)
        }

        return SolanaDerivedPrivateKey(privateKey: privateKey, chainCode: chainCode)
    }

    static func publicKey(fromPrivateKey privateKey: Data) throws -> Data {
        guard privateKey.count == privateKeyLength else {
            throw SolanaKeyDerivationError.invalidPrivateKeyLength
        }

        return try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            .publicKey
            .rawRepresentation
    }

    static func address(fromPublicKey publicKey: Data) throws -> String {
        guard publicKey.count == publicKeyLength else {
            throw SolanaKeyDerivationError.invalidPublicKeyLength
        }

        return base58Encode(Array(publicKey))
    }

    private static func parseHardenedDerivationPath(_ derivationPath: String) throws -> [Int64] {
        guard !derivationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SolanaKeyDerivationError.invalidDerivationPath
        }

        guard derivationPath == "m" || derivationPath.hasPrefix("m/") else {
            throw SolanaKeyDerivationError.invalidDerivationPath
        }

        guard derivationPath != "m" else {
            return []
        }

        return try derivationPath
            .dropFirst(2)
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { component in
                guard component.hasSuffix("'") else {
                    throw SolanaKeyDerivationError.nonHardenedDerivationComponent
                }

                let indexText = component.dropLast()
                guard !indexText.isEmpty, let index = Int64(indexText), index >= 0, index <= maxChildIndex else {
                    throw SolanaKeyDerivationError.invalidDerivationIndex
                }

                return index
            }
    }

    private static func normalizeMnemonic(_ mnemonic: String) throws -> String {
        let words = mnemonic
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !words.isEmpty else {
            throw SolanaKeyDerivationError.emptyMnemonic
        }

        return words.joined(separator: " ")
    }

    private static func bip39Seed(mnemonic: String, passphrase: String) throws -> Data {
        let password = Array(mnemonic.utf8)
        let salt = Array("mnemonic\(passphrase)".utf8)
        var output = [UInt8](repeating: 0, count: bip39SeedLength)

        let status = password.withUnsafeBufferPointer { passwordBuffer in
            salt.withUnsafeBufferPointer { saltBuffer in
                passwordBuffer.baseAddress!.withMemoryRebound(to: Int8.self, capacity: password.count) { passwordPointer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer,
                        password.count,
                        saltBuffer.baseAddress!,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        UInt32(bip39Rounds),
                        &output,
                        output.count
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw SolanaKeyDerivationError.keyDerivationFailed
        }

        return Data(output)
    }

    private static func hmacSha512(key: Data, data: Data) -> Data {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))

        key.withUnsafeBytes { keyBuffer in
            data.withUnsafeBytes { dataBuffer in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA512),
                    keyBuffer.baseAddress!,
                    key.count,
                    dataBuffer.baseAddress!,
                    data.count,
                    &output
                )
            }
        }

        return Data(output)
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
