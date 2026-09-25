import Foundation
import IrohaCrypto

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
        case unprovenChainExportMaterial(Int)
        case unprovenChainAccounts(Int)
        case unmappedChainPresentation(Int)
        case unmappedFavoriteChains(Int)
        case unprovenAuxiliarySources(Int)
        case unprovenWatchIdentities(Int)
        case unmappedMetadata(Int)
        case unmappedWalletState(Int)
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
        /// Present only when every metadata value fits current iOS destination
        /// bounds. This is read-only and does not clear the metadata blocker.
        private(set) var metadataProjections: [IOSPortableReceiveMetadata.Projection?]
        /// Prospective wallet-owned sidecars for Android-only display values.
        /// No sidecar store or transactional installer exists yet.
        private(set) var foreignDisplayPreferenceCandidates: [IOSForeignDisplayPrefs.Candidate]
        let blockers: [Blocker]

        /// Resolves candidates against fresh destination wallet IDs from a
        /// journal for this exact semantic cohort. It does not write sidecars.
        func prospectiveForeignDisplaySidecars(
            for journal: IOSPortableWalletReceiveJournalRecord.Record
        ) throws -> [IOSForeignDisplayPrefs.BoundRecord] {
            try IOSForeignDisplayPrefs.bind(
                foreignDisplayPreferenceCandidates,
                semantic: Codec.encode(snapshot), journal: journal
            )
        }

        /// Uses the semantic record sequence, not historical source positions.
        /// A future installer must read existing orders under its writer lock and
        /// recheck them in the same Core Data transaction before persistence.
        func destinationOrders(after existingOrders: [UInt32]) throws -> [UInt32] {
            try IOSPortableReceiveOrderAllocator.assign(
                walletCount: snapshot.wallets.count, after: existingOrders
            )
        }

        /// Best-effort erasure only: Swift copies may retain earlier storage.
        mutating func clearSecrets() {
            snapshot.clearSecrets()
            metadataProjections.removeAll()
            foreignDisplayPreferenceCandidates.removeAll()
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
        var chainExport = 0
        var unknownChains = 0
        var chainPresentation = 0
        var favorite = 0
        var auxiliary = 0
        var watch = 0
        var metadata = 0
        var walletState = 0

        mutating func record(
            _ source: IOSPortableWalletSemanticMaterial.Slot,
            walletIndex: Int,
            slotIndex: Int,
            approvedSubstrateGenesisIDs: Set<String>
        ) throws {
            let destination = try IOSPortableWalletReceiveInstallPlan.destination(for: source.role)
            slots.append(Slot(walletIndex: walletIndex, slotIndex: slotIndex, destination: destination))
            switch destination {
            case .substrateRoot, .evmRoot, .nativeTonRoot:
                if IOSPortableWalletReceiveInstallPlan.hasUnprovenExportMaterial(source) {
                    rootExport += 1
                }
            case .legacySubstrate:
                // A valid signer does not prove the historical source recipe.
                rootExport += 1
            case .chainAccount:
                if IOSPortableWalletReceiveInstallPlan.hasUnprovenExportMaterial(source) {
                    chainExport += 1
                }
                let chainName = try source.value(FieldID.chainName)
                let initialized = try source.number(FieldID.initializedOrFavorite)
                if !chainName.isEmpty || initialized != 1 {
                    chainPresentation += 1
                }
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
                favorite += 1
            }
        }

        var blockers: [Blocker] {
            var result = [Blocker]()
            if rootExport > 0 {
                result.append(.unprovenRootExportMaterial(rootExport))
            }
            if chainExport > 0 {
                result.append(.unprovenChainExportMaterial(chainExport))
            }
            if unknownChains > 0 {
                result.append(.unprovenChainAccounts(unknownChains))
            }
            if chainPresentation > 0 {
                result.append(.unmappedChainPresentation(chainPresentation))
            }
            if favorite > 0 {
                result.append(.unmappedFavoriteChains(favorite))
            }
            if auxiliary > 0 {
                result.append(.unprovenAuxiliarySources(auxiliary))
            }
            if watch > 0 {
                result.append(.unprovenWatchIdentities(watch))
            }
            if metadata > 0 {
                result.append(.unmappedMetadata(metadata))
            }
            if walletState > 0 {
                result.append(.unmappedWalletState(walletState))
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
        _ = try IOSPortableAndroidSourceProof.verify(encoded)
        _ = try IOSPortableIOSSourceProof.verify(encoded)
        _ = try IOSPortableWatchIdentityProof.verify(encoded)

        var snapshot = try Codec.decode(encoded)
        do {
            var inventory = Inventory()
            var metadataProjections = [IOSPortableReceiveMetadata.Projection?]()
            var foreignDisplayPreferenceCandidates = [IOSForeignDisplayPrefs.Candidate]()
            for (walletIndex, wallet) in snapshot.wallets.enumerated() {
                inventory.metadata += wallet.metadata.count
                let metadata = try? IOSPortableReceiveMetadata.decode(wallet.metadata)
                metadataProjections.append(metadata)
                if let candidate = IOSForeignDisplayPrefs.project(
                    walletIndex: walletIndex, wallet: wallet, metadata: metadata
                ) {
                    foreignDisplayPreferenceCandidates.append(candidate)
                }
                if !wallet.initialized {
                    inventory.walletState += 1
                }
                for (slotIndex, source) in wallet.slots.enumerated() {
                    try inventory.record(
                        source, walletIndex: walletIndex, slotIndex: slotIndex,
                        approvedSubstrateGenesisIDs: approvedSubstrateGenesisIDs
                    )
                }
            }
            return Plan(
                snapshot: snapshot, slots: inventory.slots,
                metadataProjections: metadataProjections,
                foreignDisplayPreferenceCandidates: foreignDisplayPreferenceCandidates,
                blockers: inventory.blockers
            )
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

    static func verify(_ encoded: Data) throws -> Int {
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
                count += try verifyWallet(wallet)
            }
        } catch {
            throw ProofError.invalidWatchIdentity
        }
        return count
    }

    private static func verifyWallet(_ wallet: Codec.Wallet) throws -> Int {
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
            case 1, 4: try verifySubstrate(slot)
            case 2: try verifyEVM(slot)
            case 3: try verifyTON(slot)
            default: throw ProofError.invalidWatchIdentity
            }
        }
        return watches.count
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

/// Assigns positive Core Data order values for a complete receiving cohort.
/// Historical source positions may tie or exceed Int32, so only record order
/// determines the new wallets' relative presentation order.
enum IOSPortableReceiveOrderAllocator {
    enum OrderError: Error, Equatable {
        case invalidExistingOrder
        case orderSpaceExhausted
    }

    static func assign(walletCount: Int, after existingOrders: [UInt32]) throws -> [UInt32] {
        guard (1 ... IOSPortableWalletSemanticMaterial.maxWallets).contains(walletCount) else {
            throw OrderError.orderSpaceExhausted
        }
        let maximum = existingOrders.max() ?? 0
        guard maximum <= UInt32(Int32.max) else { throw OrderError.invalidExistingOrder }
        guard UInt64(maximum) + UInt64(walletCount) <= UInt64(Int32.max) else {
            throw OrderError.orderSpaceExhausted
        }
        return (1 ... walletCount).map { maximum + UInt32($0) }
    }
}
