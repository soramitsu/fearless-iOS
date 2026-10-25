import Foundation
import SSFModels
import SSFUtils
import TonSwift

/// Public Core Data after-images for one journal-bound portable cohort. The
/// existing exact-replacement mapper can persist these records, but callers
/// must first establish the complete Keychain/source and transaction proofs.
/// Projection never authorizes installation or marks a backup complete.
enum IOSReceiveCoreDataProjection {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    private typealias Role = IOSPortableWalletSemanticMaterial.Role

    enum ProjectionError: Error, Equatable {
        case invalidCurrencyCatalog
        case unknownCurrency
        case unmappedWalletState
        case unmappedWatchIdentity
        case unmappedForeignDisplayPreferences
        case unmappedChainAccount
        case unmappedFavoriteState
        case unsupportedRootCombination
    }

    struct Cohort: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let records: [MetaAccountSelectionModel]
        /// These remain even when the public after-image is representable.
        let blockers: [IOSPortableWalletReceiveInstallPlan.Blocker]

        var description: String {
            "IOSReceiveCoreDataProjection.Cohort(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    // Keep the independent semantic, journal and local-policy inputs explicit.
    // swiftlint:disable function_parameter_count
    /// Currency definitions are supplied by the app's trusted catalog, never
    /// by backup metadata. Missing currency IDs use the explicit local default;
    /// unknown or ambiguous IDs fail rather than silently change the selection.
    static func project(
        semantic: Data,
        journal: IOSPortableWalletReceiveJournalRecord.Record,
        approvedSubstrateGenesisIDs: Set<String>,
        existingOrders: [UInt32],
        currencies: [Currency],
        defaultCurrencyID: String
    ) throws -> Cohort {
        try IOSPortableWalletReceiveJournalRecord.verifySemanticMaterial(semantic, for: journal)
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            semantic, approvedSubstrateGenesisIDs: approvedSubstrateGenesisIDs
        )
        defer { plan.clearSecrets() }
        let catalog = try currencyCatalog(currencies, defaultID: defaultCurrencyID)
        let orders = try plan.destinationOrders(after: existingOrders)
        let records = try plan.snapshot.wallets.enumerated().map { index, wallet in
            let metadata = try IOSPortableReceiveMetadata.decode(wallet.metadata)
            let currencyID = metadata.selectedCurrencyID ?? defaultCurrencyID
            guard let currency = catalog[currencyID] else { throw ProjectionError.unknownCurrency }
            let model = try projectWallet(
                wallet, metaID: journal.wallets[index].metaID, metadata: metadata,
                currency: currency, approvedSubstrateGenesisIDs: approvedSubstrateGenesisIDs
            )
            return MetaAccountSelectionModel(
                identifier: model.metaId, wallet: model,
                isSelected: index == plan.snapshot.selectedIndex, order: orders[index],
                displayPreferences: PersistedWalletDisplayPreferences(
                    assetFilterOptions: metadata.assetFilterOptions,
                    zeroBalanceAssetsHidden: metadata.zeroBalanceAssetsHidden ?? false
                ),
                updatesWalletPayload: true, replacesWalletChildrenExactly: true
            )
        }
        return Cohort(records: records, blockers: plan.blockers)
    }

    // swiftlint:enable function_parameter_count

    private static func currencyCatalog(_ currencies: [Currency], defaultID: String) throws -> [String: Currency] {
        guard !currencies.isEmpty, currencies.count <= 512 else { throw ProjectionError.invalidCurrencyCatalog }
        var catalog = [String: Currency]()
        for currency in currencies {
            guard !currency.id.isEmpty, catalog.updateValue(currency, forKey: currency.id) == nil else {
                throw ProjectionError.invalidCurrencyCatalog
            }
        }
        guard catalog[defaultID] != nil else { throw ProjectionError.invalidCurrencyCatalog }
        return catalog
    }

    private static func projectWallet(
        _ wallet: Codec.Wallet, metaID: String,
        metadata: IOSPortableReceiveMetadata.Projection, currency: Currency,
        approvedSubstrateGenesisIDs: Set<String>
    ) throws -> MetaAccountModel {
        guard wallet.initialized, !wallet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectionError.unmappedWalletState
        }
        guard !wallet.slots.contains(where: { $0.role == Role.watchIdentity }) else {
            // The released model has no watch-custody discriminator. Creating
            // an ordinary signed wallet here would misrepresent its custody.
            throw ProjectionError.unmappedWatchIdentity
        }
        guard metadata.androidSelectedChainID == nil, metadata.androidChainSelectFilter == nil,
              metadata.androidAssetRows == nil else { throw ProjectionError.unmappedForeignDisplayPreferences }
        let substrateRoots = wallet.slots.filter { $0.role == Role.substrateRoot || $0.role == Role.legacySubstrate }
        let evm = wallet.slots.first { $0.role == Role.evmRoot }
        let ton = wallet.slots.first { $0.role == Role.tonRoot }
        guard substrateRoots.count <= 1, substrateRoots.isEmpty || ton == nil,
              !substrateRoots.isEmpty || evm != nil || ton != nil else {
            throw ProjectionError.unsupportedRootCombination
        }
        let substrate = substrateRoots.first
        let substratePublicKey = try substrate.map { try Data($0.value(FieldID.publicKey)) }
        return try MetaAccountModel(
            metaId: metaID, name: wallet.name,
            substrateAccountId: substratePublicKey?.publicKeyToAccountId(),
            substrateCryptoType: substrate.map { try cryptoType($0.number(FieldID.cryptoType)) }
                ?? CryptoType.ed25519.rawValue,
            substratePublicKey: substratePublicKey,
            ethereumAddress: evm.map { try Data($0.value(FieldID.accountIDOrAddress)) },
            ethereumPublicKey: evm.map { try Data($0.value(FieldID.publicKey)) },
            chainAccounts: chains(in: wallet, approvedSubstrateGenesisIDs: approvedSubstrateGenesisIDs),
            assetKeysOrder: metadata.assetKeysOrder,
            canExportEthereumMnemonic: metadata.canExportEthereumMnemonic ?? false,
            unusedChainIds: metadata.unusedChainIDs, selectedCurrency: currency,
            networkManagmentFilter: metadata.networkManagementFilter,
            assetsVisibility: (metadata.assetVisibility ?? []).map {
                AssetVisibility(assetId: $0.assetID, hidden: $0.hidden)
            },
            hasBackup: false, favouriteChainIds: favorites(in: wallet, metadata: metadata),
            legacyTonAccount: ton.map(nativeTon)
        )
    }

    private static func chains(in wallet: Codec.Wallet, approvedSubstrateGenesisIDs: Set<String>) throws
        -> Set<ChainAccountModel> {
        var canonicalIDs = Set<String>()
        return try Set(wallet.slots.filter { $0.role == Role.chainAccount }.map { slot in
            let canonicalID = UniversalWalletChainAccountSupport.canonicalChainId(for: slot.key)
            guard approvedSubstrateGenesisIDs.contains(slot.key) || namedChainIDs.contains(canonicalID),
                  canonicalIDs.insert(canonicalID).inserted,
                  try slot.value(FieldID.chainName).isEmpty,
                  try slot.number(FieldID.initializedOrFavorite) == 1 else {
                throw ProjectionError.unmappedChainAccount
            }
            // Every approved inventory entry here is Substrate, and every
            // app-owned named network uses its existing non-EVM routing.
            return try ChainAccountModel(
                chainId: slot.key, accountId: Data(slot.value(FieldID.accountIDOrAddress)),
                publicKey: Data(slot.value(FieldID.publicKey)),
                cryptoType: cryptoType(slot.number(FieldID.cryptoType)), ethereumBased: false
            )
        })
    }

    private static func favorites(in wallet: Codec.Wallet, metadata: IOSPortableReceiveMetadata.Projection) throws
        -> [String] {
        if let favorites = metadata.favoriteChainIDs {
            return favorites
        }
        return try wallet.slots.filter { $0.role == Role.favoriteChain }.map { slot in
            guard try slot.number(FieldID.initializedOrFavorite) == 1 else {
                throw ProjectionError.unmappedFavoriteState
            }
            return slot.key
        }
    }

    private static func nativeTon(_ slot: Codec.Slot) throws -> LegacyTonAccount {
        let publicKey = try Data(slot.value(FieldID.publicKey))
        let address: Data
        if try slot.number(FieldID.tonAddressEncoding) == 2 {
            address = try Data(slot.value(FieldID.accountIDOrAddress))
        } else {
            // RootSigningProof already checked the exact workchain/hash.
            address = try JSONEncoder().encode(WalletV4R2(publicKey: publicKey).address())
        }
        return try LegacyTonAccount(serializedAddress: address, publicKey: publicKey, contractVersion: "v4R2")
    }

    private static func cryptoType(_ protocolID: UInt8) throws -> UInt8 {
        switch protocolID {
        case 1: return CryptoType.sr25519.rawValue
        case 2: return CryptoType.ed25519.rawValue
        case 3: return CryptoType.ecdsa.rawValue
        default: throw ProjectionError.unmappedChainAccount
        }
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
