import Foundation
import IrohaCrypto
import TonSwift
import CryptoKit
import SoraKeystore

struct TonDerivedAccount: Equatable {
    let derivationPath: String
    let privateKey: Data
    let chainCode: Data
    let publicKey: Data
    let publicKeyHex: String
    let accountHash: Data
    let addressBounceable: String
    let addressNonBounceable: String
    let testnetNonBounceable: String
}

enum TonKeyDerivation {
    static func signingAccount(for request: TonNativeSendRequest) throws -> TonDerivedAccount {
        guard let secret = request.legacyNativePrivateKey else {
            return try deriveAccount(
                mnemonic: request.mnemonic,
                passphrase: request.passphrase,
                derivationPath: request.derivationPath
            )
        }
        guard secret.count == 64 else { throw TonSendServiceError.invalidAccount }
        let privateKey = Data(secret.prefix(32))
        let publicKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey).publicKey.rawRepresentation
        guard secret.suffix(32) == publicKey else { throw TonSendServiceError.invalidAccount }
        let addresses = try TonAddressCodec.v4R2Addresses(publicKey: publicKey)
        guard try TonSwift.Address.parse(request.senderAddress).toRaw() == TonSwift.Address.parse(addresses.nonBounceable).toRaw()
        else { throw TonSendServiceError.invalidAccount }
        return TonDerivedAccount(
            derivationPath: "",
            privateKey: privateKey,
            chainCode: Data(),
            publicKey: publicKey,
            publicKeyHex: publicKey.hexString,
            accountHash: addresses.accountHash,
            addressBounceable: addresses.bounceable,
            addressNonBounceable: addresses.nonBounceable,
            testnetNonBounceable: addresses.testnetNonBounceable
        )
    }

    static func deriveAccount(
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.tonDefault
    ) throws -> TonDerivedAccount {
        let normalizedMnemonic = mnemonic
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        _ = try IRMnemonicCreator().mnemonic(fromList: normalizedMnemonic)

        let ed25519 = try SolanaKeyDerivation.deriveAccount(
            mnemonic: normalizedMnemonic,
            passphrase: passphrase,
            derivationPath: derivationPath
        )
        let addresses = try TonAddressCodec.v4R2Addresses(publicKey: ed25519.publicKey)

        return TonDerivedAccount(
            derivationPath: derivationPath,
            privateKey: ed25519.privateKey,
            chainCode: ed25519.chainCode,
            publicKey: ed25519.publicKey,
            publicKeyHex: ed25519.publicKey.hexString,
            accountHash: addresses.accountHash,
            addressBounceable: addresses.bounceable,
            addressNonBounceable: addresses.nonBounceable,
            testnetNonBounceable: addresses.testnetNonBounceable
        )
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

/// Native TON identity persisted by the released 4.1 ecosystem mapper. The original
/// JSON bytes are retained verbatim, including the workchain and contract version.
struct LegacyTonAccount: Equatable, Codable {
    let serializedAddress: Data
    let publicKey: Data
    let contractVersion: String

    init(serializedAddress: Data, publicKey: Data, contractVersion: String) throws {
        guard contractVersion == "v4R2", publicKey.count == 32,
              let address = try? JSONDecoder().decode(TonSwift.Address.self, from: serializedAddress),
              address.workchain == 0, address.hash.count == 32,
              address.hash == (try TonAddressCodec.v4R2AccountHash(publicKey: publicKey))
        else { throw TonSendServiceError.invalidAccount }
        self.serializedAddress = serializedAddress
        self.publicKey = publicKey
        self.contractVersion = contractVersion
    }

    var address: String {
        // Constructor and stored-model mapping validate this binding. Decoding also
        // validates before exposing any stored model from Codable settings.
        (try? JSONDecoder().decode(TonSwift.Address.self, from: serializedAddress))?
            .toString(bounceable: false) ?? ""
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            serializedAddress: values.decode(Data.self, forKey: .serializedAddress),
            publicKey: values.decode(Data.self, forKey: .publicKey),
            contractVersion: values.decode(String.self, forKey: .contractVersion)
        )
    }

    func validatedPrivateKey(_ secret: Data) throws -> Data {
        guard secret.count == 64 else { throw TonSendServiceError.invalidAccount }
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: secret.prefix(32))
        guard key.publicKey.rawRepresentation == publicKey,
              secret.suffix(32) == publicKey else { throw TonSendServiceError.invalidAccount }
        return secret
    }

    func mnemonic(from storedPhrase: Data) throws -> LegacyTonMnemonic {
        guard let phrase = String(data: storedPhrase, encoding: .utf8) else {
            throw TonSendServiceError.invalidAccount
        }
        let words = phrase.components(separatedBy: " ")
        guard !words.isEmpty, words.allSatisfy({ TonSwift.Mnemonic.words.contains($0.lowercased()) }) else {
            throw TonSendServiceError.invalidAccount
        }
        let keypair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: words)
        _ = try validatedPrivateKey(keypair.privateKey.data)
        return LegacyTonMnemonic(phrase: phrase)
    }

    func signingCredentials(keystore: KeystoreProtocol, metaId: String) throws -> TonSigningCredentials {
        let key: Data
        do {
            key = try validatedPrivateKey(keystore.fetchKey(for: KeystoreTagV2.tonSecretKeyTagForMetaId(metaId)))
        } catch KeystoreError.noKeyFound {
            let phrase = try mnemonic(from: keystore.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(metaId)))
            key = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: phrase.allWords()).privateKey.data
        }
        return TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: key)
    }
}

/// The released TON entropy tag stores the phrase itself, not BIP39 entropy.
final class LegacyTonMnemonic: NSObject, IRMnemonicProtocol {
    private let phrase: String
    init(phrase: String) { self.phrase = phrase }
    func entropy() -> Data { Data(phrase.utf8) }
    func word(at index: UInt) -> String { allWords()[Int(index)] }
    func numberOfWords() -> UInt { UInt(allWords().count) }
    func allWords() -> [String] { phrase.components(separatedBy: " ") }
    func toString() -> String { phrase }
}
