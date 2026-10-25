import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels

/// Read-only signing proof for a role-5 account on a trusted Substrate genesis.
/// The semantic format does not identify a chain's ecosystem. Callers must
/// supply genesis IDs from the reviewed release inventory, never from the
/// payload itself. Unlisted and named chains remain explicitly unproven.
/// This does not authorize restore, installation, signing or backup completion.
enum IOSPortableRegularSubstrateChainProof {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias Role = IOSPortableWalletSemanticMaterial.Role
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID

    enum ProofError: Error, Equatable {
        case invalidApprovedChainInventory
        case invalidChainIdentity
    }

    struct Counts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let verifiedAccounts: Int
        let unprovenAccounts: Int

        var description: String { "IOSPortableRegularSubstrateChainProof.Counts(<redacted>)" }
        var debugDescription: String { description }
    }

    static func verify(_ encoded: Data, approvedSubstrateGenesisIDs: Set<String>) throws -> Counts {
        guard approvedSubstrateGenesisIDs.allSatisfy(isCanonicalGenesisID) else {
            throw ProofError.invalidApprovedChainInventory
        }
        var decoded: Codec.Snapshot
        do {
            decoded = try Codec.decode(encoded)
        } catch {
            throw ProofError.invalidChainIdentity
        }
        defer { decoded.clearSecrets() }

        var verified = 0
        var unproven = 0
        do {
            for wallet in decoded.wallets {
                for slot in wallet.slots where slot.role == Role.chainAccount {
                    guard approvedSubstrateGenesisIDs.contains(slot.key) else {
                        // This includes known app-owned networks and any future
                        // chain whose ecosystem has not been independently proven.
                        unproven += 1
                        continue
                    }
                    try verifySubstrate(slot, portableID: wallet.portableID)
                    verified += 1
                }
            }
        } catch {
            throw ProofError.invalidChainIdentity
        }
        return Counts(verifiedAccounts: verified, unprovenAccounts: unproven)
    }

    private static func isCanonicalGenesisID(_ chainID: String) -> Bool {
        chainID.utf8.count == 64 && chainID.utf8.allSatisfy {
            (48 ... 57).contains($0) || (97 ... 102).contains($0)
        }
    }

    private static func verifySubstrate(_ slot: Codec.Slot, portableID: [UInt8]) throws {
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let accountID = Data(try slot.value(FieldID.accountIDOrAddress))
        guard accountID.count == 32,
              try publicKey.publicKeyToAccountId() == accountID else {
            throw ProofError.invalidChainIdentity
        }
        let cryptoType = try cryptoType(slot.number(FieldID.cryptoType))
        let message = proofMessage(
            portableID: portableID, chainID: slot.key, accountID: accountID,
            cryptoType: try slot.number(FieldID.cryptoType), publicKey: publicKey
        )
        let signature = try ImportedRootSigner(
            secret: Data(try slot.value(FieldID.privateKey)),
            publicKey: publicKey, cryptoType: cryptoType, ethereumBased: false
        ).sign(message)
        let verified: Bool
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
        guard verified else { throw ProofError.invalidChainIdentity }
    }

    private static func cryptoType(_ protocolID: UInt8) throws -> CryptoType {
        switch protocolID {
        case 1: return .sr25519
        case 2: return .ed25519
        case 3: return .ecdsa
        default: throw ProofError.invalidChainIdentity
        }
    }

    private static func proofMessage(
        portableID: [UInt8], chainID: String, accountID: Data,
        cryptoType: UInt8, publicKey: Data
    ) -> Data {
        Data("FPBK-IMPORTED-CHAIN-PROOF-v1".utf8) + Data(portableID) +
            Data(chainID.utf8) + Data([cryptoType]) + accountID + publicKey
    }
}
