import Foundation
import IrohaCrypto

/// Checks public watch identities before a received cohort can be considered
/// for installation. An address-only EVM watch has no public key to derive,
/// so its exact 20-byte address is retained without claiming ownership.
enum IOSPortableWatchIdentityProof {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias Role = IOSPortableWalletSemanticMaterial.Role
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID

    enum ProofError: Error, Equatable {
        case invalidWatchIdentity
    }

    static func verify(
        _ encoded: Data, approvedSubstrateGenesisIDs: Set<String> = []
    ) throws -> Int {
        guard approvedSubstrateGenesisIDs.allSatisfy(isCanonicalGenesisID) else {
            throw ProofError.invalidWatchIdentity
        }
        var snapshot: Codec.Snapshot
        do {
            snapshot = try Codec.decode(encoded)
        } catch {
            throw ProofError.invalidWatchIdentity
        }
        defer { snapshot.clearSecrets() }

        var count = 0
        do {
            for wallet in snapshot.wallets {
                count += try verifyWallet(
                    wallet, approvedSubstrateGenesisIDs: approvedSubstrateGenesisIDs
                )
            }
        } catch {
            throw ProofError.invalidWatchIdentity
        }
        return count
    }

    private static func verifyWallet(
        _ wallet: Codec.Wallet, approvedSubstrateGenesisIDs: Set<String>
    ) throws -> Int {
        let watches = wallet.slots.filter { $0.role == Role.watchIdentity }
        guard !watches.isEmpty else { return 0 }
        guard wallet.slots.allSatisfy({
            $0.role == Role.watchIdentity || $0.role == Role.favoriteChain
        }) else { throw ProofError.invalidWatchIdentity }
        var seen = Set<String>()
        for slot in watches {
            let ecosystem = try slot.number(FieldID.watchEcosystem)
            let identity = ecosystem == 4
                ? "chain:" + (try Codec.strictText(slot.value(FieldID.watchChainID), allowEmpty: false))
                : "root:\(ecosystem)"
            guard seen.insert(identity).inserted else { throw ProofError.invalidWatchIdentity }
            switch ecosystem {
            case 1: try verifySubstrate(slot)
            case 2: try verifyEVM(slot)
            case 3: try verifyTON(slot)
            case 4:
                let chainID = try Codec.strictText(slot.value(FieldID.watchChainID), allowEmpty: false)
                guard approvedSubstrateGenesisIDs.contains(chainID) else {
                    throw ProofError.invalidWatchIdentity
                }
                try verifySubstrate(slot)
            default: throw ProofError.invalidWatchIdentity
            }
        }
        return watches.count
    }

    private static func isCanonicalGenesisID(_ chainID: String) -> Bool {
        chainID.utf8.count == 64 && chainID.utf8.allSatisfy {
            (48 ... 57).contains($0) || (97 ... 102).contains($0)
        }
    }

    private static func verifySubstrate(_ slot: Codec.Slot) throws {
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let accountID = Data(try slot.value(FieldID.accountIDOrAddress))
        let ecdsa = try slot.number(FieldID.cryptoType) == 3
        guard publicKey.count == (ecdsa ? 33 : 32), accountID.count == 32,
              try publicKey.publicKeyToAccountId() == accountID else {
            throw ProofError.invalidWatchIdentity
        }
        if ecdsa {
            _ = try SECPublicKey(rawData: publicKey)
        }
    }

    private static func verifyEVM(_ slot: Codec.Slot) throws {
        let address = Data(try slot.value(FieldID.accountIDOrAddress))
        guard address.count == 20 else {
            throw ProofError.invalidWatchIdentity
        }
        if let key = slot.fields.first(where: { $0.id == FieldID.publicKey })?.value {
            let publicKey = Data(key)
            guard publicKey.count == 33,
                  try publicKey.ethereumAddressFromPublicKey() == address else {
                throw ProofError.invalidWatchIdentity
            }
        }
    }

    private static func verifyTON(_ slot: Codec.Slot) throws {
        guard let key = slot.fields.first(where: { $0.id == FieldID.publicKey })?.value,
              key.count == 32 else { throw ProofError.invalidWatchIdentity }
        let publicKey = Data(key)
        let address = Data(try slot.value(FieldID.accountIDOrAddress))
        switch try slot.number(FieldID.tonAddressEncoding) {
        case 1:
            guard address.count == 33, address.first == 0,
                  Data(address.dropFirst()) == (try TonAddressCodec.v4R2AccountHash(publicKey: publicKey)) else {
                throw ProofError.invalidWatchIdentity
            }
        case 2:
            _ = try LegacyTonAccount(
                serializedAddress: address, publicKey: publicKey, contractVersion: "v4R2"
            )
        default:
            throw ProofError.invalidWatchIdentity
        }
    }
}
