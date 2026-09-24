import Foundation

/// A read-only receiving inventory. No caller may treat this as permission to
/// write Core Data or Keychain entries; the cohort installer is not available.
enum IOSPortableWalletReceiveInstallPlan {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias Role = IOSPortableWalletSemanticMaterial.Role
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID

    enum Destination: Equatable {
        case substrateRoot
        case evmRoot
        case nativeTonRoot
        case legacySubstrate
        case chainAccount
        case favoriteChain
        case auxiliarySource
        case watchIdentity
    }

    enum Blocker: Equatable {
        case unprovenRootExportMaterial(Int)
        case unprovenChainAccounts(Int)
        case unprovenAuxiliarySources(Int)
        case unprovenWatchIdentities(Int)
        case transactionalInstallerUnavailable
    }

    struct Slot: Equatable {
        let walletIndex: Int
        let slotIndex: Int
        let destination: Destination
    }

    struct Plan: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        /// Includes every wallet, selected index, metadata item and field.
        /// This is sensitive plaintext; the caller must discard it promptly.
        private(set) var snapshot: IOSPortableWalletSemanticMaterial.Snapshot
        let slots: [Slot]
        let blockers: [Blocker]

        /// Best-effort erasure only: Swift copies may retain earlier storage.
        mutating func clearSecrets() {
            snapshot.clearSecrets()
        }

        var description: String {
            "IOSPortableWalletReceiveInstallPlan.Plan(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    private struct Inventory {
        var slots = [Slot]()
        var rootExport = 0
        var unknownChains = 0
        var auxiliary = 0
        var watch = 0

        mutating func record(
            _ source: IOSPortableWalletSemanticMaterial.Slot,
            walletIndex: Int,
            slotIndex: Int,
            approvedSubstrateGenesisIDs: Set<String>
        ) throws {
            let destination = try IOSPortableWalletReceiveInstallPlan.destination(for: source.role)
            slots.append(Slot(walletIndex: walletIndex, slotIndex: slotIndex, destination: destination))
            switch destination {
            case .substrateRoot, .evmRoot, .nativeTonRoot, .legacySubstrate:
                if IOSPortableWalletReceiveInstallPlan.hasUnprovenExportMaterial(source) {
                    rootExport += 1
                }
            case .chainAccount:
                let canonical = UniversalWalletChainAccountSupport.canonicalChainId(for: source.key)
                if !approvedSubstrateGenesisIDs.contains(source.key),
                   !IOSPortableWalletReceiveInstallPlan.namedChainIDs.contains(canonical) {
                    unknownChains += 1
                }
            case .auxiliarySource:
                auxiliary += 1
            case .watchIdentity:
                watch += 1
            case .favoriteChain:
                break
            }
        }

        var blockers: [Blocker] {
            var result = [Blocker]()
            if rootExport > 0 {
                result.append(.unprovenRootExportMaterial(rootExport))
            }
            if unknownChains > 0 {
                result.append(.unprovenChainAccounts(unknownChains))
            }
            if auxiliary > 0 {
                result.append(.unprovenAuxiliarySources(auxiliary))
            }
            if watch > 0 {
                result.append(.unprovenWatchIdentities(watch))
            }
            result.append(.transactionalInstallerUnavailable)
            return result
        }
    }

    static func prepare(
        _ encoded: Data,
        approvedSubstrateGenesisIDs: Set<String>
    ) throws -> Plan {
        // Each verifier fails closed for invalid original signing identity.
        // The approved genesis inventory must come from reviewed app policy.
        _ = try IOSPortableRootSigningProof.verify(encoded)
        _ = try IOSPortableRegularSubstrateChainProof.verify(
            encoded, approvedSubstrateGenesisIDs: approvedSubstrateGenesisIDs
        )
        _ = try IOSPortableNamedChainProof.verify(encoded)

        var snapshot = try Codec.decode(encoded)
        do {
            var inventory = Inventory()
            for (walletIndex, wallet) in snapshot.wallets.enumerated() {
                for (slotIndex, source) in wallet.slots.enumerated() {
                    try inventory.record(
                        source, walletIndex: walletIndex, slotIndex: slotIndex,
                        approvedSubstrateGenesisIDs: approvedSubstrateGenesisIDs
                    )
                }
            }
            return Plan(snapshot: snapshot, slots: inventory.slots, blockers: inventory.blockers)
        } catch {
            snapshot.clearSecrets()
            throw error
        }
    }

    private static func destination(for role: UInt8) throws -> Destination {
        switch role {
        case Role.substrateRoot: return .substrateRoot
        case Role.evmRoot: return .evmRoot
        case Role.tonRoot: return .nativeTonRoot
        case Role.legacySubstrate: return .legacySubstrate
        case Role.chainAccount: return .chainAccount
        case Role.favoriteChain: return .favoriteChain
        case Role.auxiliarySource: return .auxiliarySource
        case Role.watchIdentity: return .watchIdentity
        default: throw Codec.CodecError.invalidMaterial
        }
    }

    private static func hasUnprovenExportMaterial(_ slot: Codec.Slot) -> Bool {
        let optionalSources: Set<UInt8> = [
            FieldID.nonce, FieldID.entropy, FieldID.seed,
            FieldID.derivationPath, FieldID.mnemonic
        ]
        let privateKeyLength = slot.fields.first(where: { $0.id == FieldID.privateKey })?.value.count ?? 0
        return slot.fields.contains { optionalSources.contains($0.id) } || privateKeyLength > 32
    }

    private static let namedChainIDs: Set<String> = [
        UniversalWalletRegistry.bitcoinMainnet.chainId,
        UniversalWalletRegistry.bitcoinTestnet.chainId,
        UniversalWalletRegistry.taira.chainId,
        UniversalWalletRegistry.solanaMainnet.chainId,
        UniversalWalletRegistry.solanaDevnet.chainId,
        UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
        UniversalWalletRegistry.nexus.chainId
    ]
}
