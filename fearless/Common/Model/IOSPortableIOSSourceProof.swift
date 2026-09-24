import Foundation
import IrohaCrypto

/// Checks that iOS Keychain bytes retained as auxiliary sources agree with the
/// signing and export fields produced from the same captured wallet. Historical
/// wallet-wide or unused scoped items remain counted as unproven. This is a
/// read-only source proof, not evidence of an atomic capture or safe install.
enum IOSPortableIOSSourceProof {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    private typealias Role = IOSPortableWalletSemanticMaterial.Role

    enum ProofError: Error, Equatable {
        case invalidSource
    }

    struct Counts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let verifiedSources: Int
        let unprovenSources: Int

        var description: String {
            "IOSPortableIOSSourceProof.Counts(<redacted>)"
        }

        var debugDescription: String {
            description
        }
    }

    private struct Destination {
        let firstSlotIndex: Int
        var chainIDs: Set<String>
    }

    static func verify(_ encoded: Data) throws -> Counts {
        var snapshot: Codec.Snapshot
        do {
            snapshot = try Codec.decode(encoded)
        } catch {
            throw ProofError.invalidSource
        }
        defer { snapshot.clearSecrets() }

        var verified = 0
        var unproven = 0
        do {
            for wallet in snapshot.wallets {
                var destinations = [Data: Destination]()
                for (slotIndex, source) in wallet.slots.enumerated() where source.role == Role.auxiliarySource {
                    guard try source.number(FieldID.sourcePlatform) == 2 else { continue }
                    guard try source.number(FieldID.sourceRecipe) == 0,
                          (try source.number(FieldID.sourceFormat)) == 1 else {
                        throw ProofError.invalidSource
                    }
                    let sourceRole = try source.number(FieldID.sourceSlotRole)
                    let binding = try source.number(FieldID.bindingKind)
                    let bytes = try source.value(FieldID.sourceBytes)
                    guard (1 ... 4096).contains(bytes.count) else { throw ProofError.invalidSource }
                    let accountID = binding == 5 ? try source.value(FieldID.bindingAccountID) : []
                    let destination = Data([sourceRole]) + Data(accountID)
                    let chainID = binding == 5
                        ? try Codec.strictText(source.value(FieldID.bindingChainID), allowEmpty: false) : nil
                    if var prior = destinations[destination] {
                        guard let chainID, !prior.chainIDs.isEmpty,
                              prior.chainIDs.insert(chainID).inserted,
                              try wallet.slots[prior.firstSlotIndex].value(FieldID.sourceBytes) == bytes else {
                            throw ProofError.invalidSource
                        }
                        destinations[destination] = prior
                    } else {
                        let chainIDs = Set(chainID.map { [$0] } ?? [])
                        destinations[destination] = Destination(firstSlotIndex: slotIndex, chainIDs: chainIDs)
                    }

                    if try prove(sourceRole, binding: binding, bytes: bytes, source: source, wallet: wallet) {
                        verified += 1
                    } else {
                        unproven += 1
                    }
                }
                try requireRootAndIndependentChainSources(in: wallet)
            }
        } catch {
            throw ProofError.invalidSource
        }
        return Counts(verifiedSources: verified, unprovenSources: unproven)
    }

    // The released Keychain-role table is deliberately closed here.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func prove(
        _ role: UInt8, binding: UInt8, bytes: [UInt8],
        source: Codec.Slot, wallet: Codec.Wallet
    ) throws -> Bool {
        if role == 9 {
            guard binding == 1, bytes == Array(UniversalWalletSeedBridge.contract.utf8) else {
                throw ProofError.invalidSource
            }
            guard let root = wallet.slots.first(where: { $0.role == Role.substrateRoot }) else { return false }
            guard !root.fields.contains(where: { $0.id == FieldID.entropy }),
                  let seed = root.fields.first(where: { $0.id == FieldID.seed })?.value,
                  (try? UniversalWalletSeedBridge.mnemonic(fromWalletSeed: Data(seed))) != nil else {
                throw ProofError.invalidSource
            }
            return true
        }

        if binding == 1, role == 4 {
            var matched = false
            for root in wallet.slots {
                let fieldID: UInt8
                switch root.role {
                case Role.substrateRoot, Role.evmRoot: fieldID = FieldID.entropy
                case Role.tonRoot: fieldID = FieldID.mnemonic
                default: continue
                }
                if let value = root.fields.first(where: { $0.id == fieldID })?.value {
                    guard value == bytes else { throw ProofError.invalidSource }
                    matched = true
                }
            }
            return matched
        }

        let primary: Codec.Slot?
        switch binding {
        case 1 where [1, 5, 7].contains(role),
             2 where [1, 4, 5, 7].contains(role):
            primary = wallet.slots.first(where: { $0.role == Role.substrateRoot })
        case 1 where [2, 6, 8].contains(role),
             3 where [2, 4, 6, 8].contains(role):
            primary = wallet.slots.first(where: { $0.role == Role.evmRoot })
        case 1 where role == 3, 4 where [3, 4].contains(role):
            primary = wallet.slots.first(where: { $0.role == Role.tonRoot })
        case 5:
            let chainID = try Codec.strictText(source.value(FieldID.bindingChainID), allowEmpty: false)
            let accountID = try source.value(FieldID.bindingAccountID)
            primary = try wallet.slots.first { candidate in
                guard candidate.role == Role.chainAccount, candidate.key == chainID else { return false }
                return try candidate.value(FieldID.accountIDOrAddress) == accountID
            }
            guard primary != nil else { throw ProofError.invalidSource }
            if [1, 2].contains(role) {
                let canonical = UniversalWalletChainAccountSupport.canonicalChainId(for: chainID)
                if [UniversalWalletRegistry.bitcoinMainnet.chainId,
                    UniversalWalletRegistry.bitcoinTestnet.chainId,
                    UniversalWalletRegistry.taira.chainId].contains(canonical) {
                    return false
                }
                guard let primary else { throw ProofError.invalidSource }
                let expectedRole = try chainSecretRole(primary)
                if role != expectedRole {
                    return false
                }
            } else if role == 3 {
                return false
            } else if [5, 6, 7, 8].contains(role) {
                guard let primary else { throw ProofError.invalidSource }
                let expectedRole = try chainSecretRole(primary)
                if ([5, 7].contains(role) && expectedRole == 2) ||
                    ([6, 8].contains(role) && expectedRole == 1) {
                    return false
                }
            }
        default:
            return false
        }
        guard let primary else { return false }
        let fieldID: UInt8
        switch role {
        case 1, 2, 3: fieldID = FieldID.privateKey
        case 4: fieldID = primary.role == Role.tonRoot ? FieldID.mnemonic : FieldID.entropy
        case 5, 6: fieldID = FieldID.seed
        case 7, 8: fieldID = FieldID.derivationPath
        default: throw ProofError.invalidSource
        }
        guard let value = primary.fields.first(where: { $0.id == fieldID })?.value,
              value == bytes else { throw ProofError.invalidSource }
        return true
    }

    private static func chainSecretRole(_ chain: Codec.Slot) throws -> UInt8 {
        let publicKey = Data(try chain.value(FieldID.publicKey))
        let accountID = Data(try chain.value(FieldID.accountIDOrAddress))
        return (try? publicKey.ethereumAddressFromPublicKey()) == accountID ? 2 : 1
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func requireRootAndIndependentChainSources(in wallet: Codec.Wallet) throws {
        let iosSources = try wallet.slots.filter { slot in
            guard slot.role == Role.auxiliarySource else { return false }
            return try slot.number(FieldID.sourcePlatform) == 2
        }
        guard !iosSources.isEmpty else { return }
        for primary in wallet.slots {
            let requiredRole: UInt8
            switch primary.role {
            case Role.substrateRoot: requiredRole = 1
            case Role.evmRoot: requiredRole = 2
            case Role.tonRoot: requiredRole = 4
            case Role.chainAccount:
                let canonical = UniversalWalletChainAccountSupport.canonicalChainId(for: primary.key)
                if [UniversalWalletRegistry.bitcoinMainnet.chainId,
                    UniversalWalletRegistry.bitcoinTestnet.chainId,
                    UniversalWalletRegistry.taira.chainId,
                    UniversalWalletRegistry.solanaMainnet.chainId,
                    UniversalWalletRegistry.solanaDevnet.chainId,
                    UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
                    UniversalWalletRegistry.nexus.chainId].contains(canonical) {
                    continue
                }
                requiredRole = try chainSecretRole(primary)
            default: continue
            }
            let match = try iosSources.contains { source in
                guard try source.number(FieldID.sourceSlotRole) == requiredRole else { return false }
                let binding = try source.number(FieldID.bindingKind)
                if primary.role == Role.chainAccount {
                    guard binding == 5 else { return false }
                    let chainID = try Codec.strictText(source.value(FieldID.bindingChainID), allowEmpty: false)
                    let accountID = try source.value(FieldID.bindingAccountID)
                    let primaryAccountID = try primary.value(FieldID.accountIDOrAddress)
                    return chainID == primary.key && accountID == primaryAccountID
                }
                return binding != 5
            }
            guard match else { throw ProofError.invalidSource }
        }
    }
}
