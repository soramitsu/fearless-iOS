import CryptoKit
import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels
import TonSwift

/// Read-only proof for signed *root* slots in a decoded portable payload. This
/// proves neither chain-account derivation nor installability, export, backup
/// completion or replacement-device recovery. A receiving installer must run
/// its complete per-chain proof before writing Core Data or Keychain entries.
enum IOSPortableRootSigningProof {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias Role = IOSPortableWalletSemanticMaterial.Role
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID

    enum ProofError: Error, Equatable {
        case invalidRootIdentity
    }

    struct Counts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let wallets: Int
        let substrateRoots: Int
        let evmRoots: Int
        let nativeTonRoots: Int
        let legacySubstrateRoots: Int

        var description: String { "IOSPortableRootSigningProof.Counts(<redacted>)" }
        var debugDescription: String { description }
    }

    static func verify(_ encoded: Data) throws -> Counts {
        var decoded: Codec.Snapshot
        do {
            decoded = try Codec.decode(encoded)
        } catch {
            throw ProofError.invalidRootIdentity
        }
        defer { decoded.clearSecrets() }

        var substrate = 0
        var evm = 0
        var ton = 0
        var legacy = 0
        do {
            for wallet in decoded.wallets {
                for slot in wallet.slots {
                    switch slot.role {
                    case Role.substrateRoot, Role.legacySubstrate:
                        try verifySubstrate(slot, portableID: wallet.portableID)
                        if slot.role == Role.substrateRoot { substrate += 1 } else { legacy += 1 }
                    case Role.evmRoot:
                        try verifyEVM(slot, portableID: wallet.portableID)
                        evm += 1
                    case Role.tonRoot:
                        try verifyTON(slot, portableID: wallet.portableID)
                        ton += 1
                    default:
                        // The chain and watch identities require a separate,
                        // complete verifier; they are never counted as proven.
                        break
                    }
                }
            }
        } catch {
            throw ProofError.invalidRootIdentity
        }
        return Counts(
            wallets: decoded.wallets.count, substrateRoots: substrate,
            evmRoots: evm, nativeTonRoots: ton, legacySubstrateRoots: legacy
        )
    }

    private static func verifySubstrate(_ slot: Codec.Slot, portableID: [UInt8]) throws {
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let accountID = Data(try slot.value(FieldID.accountIDOrAddress))
        let expectedID = try publicKey.publicKeyToAccountId()
        if slot.role == Role.legacySubstrate {
            guard let address = String(data: accountID, encoding: .utf8),
                  try SS58AddressFactory().accountId(from: address) == expectedID else {
                throw ProofError.invalidRootIdentity
            }
        } else {
            guard accountID == expectedID else { throw ProofError.invalidRootIdentity }
        }
        let cryptoType = try cryptoType(slot.number(FieldID.cryptoType))
        try verifySignature(
            slot, portableID: portableID, publicKey: publicKey,
            cryptoType: cryptoType, ethereumBased: false
        )
    }

    private static func verifyEVM(_ slot: Codec.Slot, portableID: [UInt8]) throws {
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let address = Data(try slot.value(FieldID.accountIDOrAddress))
        let privateKey = Data(try slot.value(FieldID.privateKey))
        guard try publicKey.ethereumAddressFromPublicKey() == address,
              try SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: privateKey))
              .publicKey().rawData().ethereumAddressFromPublicKey() == address else {
            throw ProofError.invalidRootIdentity
        }
        try verifySignature(
            slot, portableID: portableID, publicKey: publicKey,
            cryptoType: .ecdsa, ethereumBased: true
        )
    }

    private static func verifyTON(_ slot: Codec.Slot, portableID: [UInt8]) throws {
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let secret = Data(try slot.value(FieldID.privateKey))
        // Android V3 stores the 32-byte ED25519 seed plus a mnemonic in field
        // 5; released native iOS stores seed||public (64 bytes) and field 12.
        guard publicKey.count == 32, [32, 64].contains(secret.count) else {
            throw ProofError.invalidRootIdentity
        }
        if secret.count == 64 {
            guard secret.suffix(32) == publicKey else { throw ProofError.invalidRootIdentity }
        }
        let signer = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(secret.prefix(32)))
        guard signer.publicKey.rawRepresentation == publicKey else { throw ProofError.invalidRootIdentity }

        try verifyTONAddress(slot, publicKey: publicKey)
        try verifyTONMnemonic(slot, secret: secret)
        let message = proofMessage(portableID: portableID, role: slot.role, publicKey: publicKey)
        let signature = try signer.signature(for: message)
        guard signer.publicKey.isValidSignature(signature, for: message) else {
            throw ProofError.invalidRootIdentity
        }
    }

    private static func verifyTONAddress(_ slot: Codec.Slot, publicKey: Data) throws {
        let address = Data(try slot.value(FieldID.accountIDOrAddress))
        switch try slot.number(FieldID.tonAddressEncoding) {
        case 1:
            guard address.count == 33, address[0] == 0,
                  Data(address.dropFirst()) == (try TonAddressCodec.v4R2AccountHash(publicKey: publicKey)) else {
                throw ProofError.invalidRootIdentity
            }
        case 2:
            _ = try LegacyTonAccount(
                serializedAddress: address, publicKey: publicKey, contractVersion: "v4R2"
            )
        default:
            throw ProofError.invalidRootIdentity
        }
    }

    private static func verifyTONMnemonic(_ slot: Codec.Slot, secret: Data) throws {
        let phrase = slot.fields.first(where: { $0.id == FieldID.mnemonic })?.value
        let androidMnemonic = secret.count == 32
            ? slot.fields.first(where: { $0.id == FieldID.seed })?.value : nil
        guard secret.count != 32 || androidMnemonic != nil else { throw ProofError.invalidRootIdentity }
        for phraseBytes in [phrase, androidMnemonic].compactMap({ $0 }) {
            guard let phrase = String(bytes: phraseBytes, encoding: .utf8) else {
                throw ProofError.invalidRootIdentity
            }
            let words = phrase.components(separatedBy: " ")
            guard !words.isEmpty, words.allSatisfy({ TonSwift.Mnemonic.words.contains($0.lowercased()) }),
                  try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: words)
                  .privateKey.data.prefix(32) == secret.prefix(32) else {
                throw ProofError.invalidRootIdentity
            }
        }
    }

    private static func verifySignature(
        _ slot: Codec.Slot, portableID: [UInt8], publicKey: Data,
        cryptoType: CryptoType, ethereumBased: Bool
    ) throws {
        let secret = Data(try slot.value(FieldID.privateKey))
        let message = proofMessage(portableID: portableID, role: slot.role, publicKey: publicKey)
        let signature = try ImportedRootSigner(
            secret: secret, publicKey: publicKey,
            cryptoType: cryptoType, ethereumBased: ethereumBased
        ).sign(message)
        let verified: Bool
        if ethereumBased {
            verified = try SECSignatureVerifier().verify(
                signature, forOriginalData: message.keccak256(),
                usingPublicKey: SECPublicKey(rawData: publicKey)
            )
        } else {
            switch cryptoType {
            case .sr25519:
                verified = try SNSignatureVerifier().verify(
                    SNSignature(rawData: signature.rawData()),
                    forOriginalData: message, using: SNPublicKey(rawData: publicKey)
                )
            case .ed25519:
                verified = try EDSignatureVerifier().verify(
                    signature, forOriginalData: message,
                    usingPublicKey: EDPublicKey(rawData: publicKey)
                )
            case .ecdsa:
                verified = try SECSignatureVerifier().verify(
                    signature, forOriginalData: message.blake2b32(),
                    usingPublicKey: SECPublicKey(rawData: publicKey)
                )
            }
        }
        guard verified else { throw ProofError.invalidRootIdentity }
    }

    private static func cryptoType(_ protocolID: UInt8) throws -> CryptoType {
        switch protocolID {
        case 1: return .sr25519
        case 2: return .ed25519
        case 3: return .ecdsa
        default: throw ProofError.invalidRootIdentity
        }
    }

    private static func proofMessage(portableID: [UInt8], role: UInt8, publicKey: Data) -> Data {
        Data("FPBK-IMPORTED-ROOT-PROOF-v1".utf8) + Data(portableID) + Data([role]) + publicKey
    }
}

private final class ImportedRootSigner: SigningWrapperProtocol {
    let secret: Data
    let publicKey: Data
    let cryptoType: CryptoType
    let ethereumBased: Bool

    init(secret: Data, publicKey: Data, cryptoType: CryptoType, ethereumBased: Bool) {
        self.secret = secret
        self.publicKey = publicKey
        self.cryptoType = cryptoType
        self.ethereumBased = ethereumBased
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        if ethereumBased { return try signEthereumEcdsa(originalData, secretKey: secret) }
        switch cryptoType {
        case .sr25519:
            return try signSr25519(originalData, secretKeyData: secret, publicKeyData: publicKey)
        case .ed25519:
            return try signEd25519(originalData, secretKey: secret)
        case .ecdsa:
            return try signEcdsa(originalData, secretKey: secret)
        }
    }
}
