import Foundation

/// A read-only inverse of the portable display-metadata encoding. It retains
/// absent versus explicitly empty values; an installer still has to resolve
/// the selected currency against a trusted local catalog and write the full
/// Core Data after-image before any wallet can be accepted.
enum IOSPortableReceiveMetadata {
    typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias MetadataID = IOSPortableWalletSemanticMaterial.MetadataID

    enum ProjectionError: Error, Equatable {
        case invalidMetadata
    }

    struct Visibility: Equatable {
        let assetID: String
        let hidden: Bool
    }

    struct Projection: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let assetKeysOrder: [String]?
        let unusedChainIDs: [String]?
        let selectedCurrencyID: String?
        let networkManagementFilter: String?
        let assetVisibility: [Visibility]?
        let favoriteChainIDs: [String]?
        let assetFilterOptions: [String]?
        let zeroBalanceAssetsHidden: Bool?
        let canExportEthereumMnemonic: Bool?
        /// Android display preferences are retained exactly for a future
        /// destination mapping; nil differs from an explicitly empty value.
        /// Neither value is the iOS networkManagementFilter (metadata ID 4).
        let androidSelectedChainID: String?
        let androidChainSelectFilter: String?
        /// Raw Android wallet-scoped asset presentation has no iOS Core Data
        /// destination yet. A receiver must preserve it or refuse install.
        let androidAssetRows: [Codec.AssetRowPresentation]?

        var description: String {
            "IOSPortableReceiveMetadata.Projection(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    private struct State {
        var order: [String]?
        var unused: [String]?
        var currency: String?
        var networkFilter: String?
        var visibility: [Visibility]?
        var favorites: [String]?
        var assetFilters: [String]?
        var zeroBalanceHidden: Bool?
        var canExportEthereumMnemonic: Bool?
        var androidSelectedChainID: String?
        var androidChainSelectFilter: String?
        var androidAssetRows: [Codec.AssetRowPresentation]?

        var projection: Projection {
            Projection(
                assetKeysOrder: order, unusedChainIDs: unused,
                selectedCurrencyID: currency, networkManagementFilter: networkFilter,
                assetVisibility: visibility, favoriteChainIDs: favorites,
                assetFilterOptions: assetFilters, zeroBalanceAssetsHidden: zeroBalanceHidden,
                canExportEthereumMnemonic: canExportEthereumMnemonic,
                androidSelectedChainID: androidSelectedChainID,
                androidChainSelectFilter: androidChainSelectFilter,
                androidAssetRows: androidAssetRows
            )
        }
    }

    static func decode(_ metadata: [Codec.Metadata]) throws -> Projection {
        guard metadata.count <= Int(MetadataID.androidAssetRowPresentation) else {
            throw ProjectionError.invalidMetadata
        }
        var state = State()
        var priorID: UInt8 = 0

        for item in metadata {
            guard item.id > priorID, (try? Codec.validateMetadata(item)) != nil else {
                throw ProjectionError.invalidMetadata
            }
            priorID = item.id
            if try !decodeFirst(item, into: &state) {
                try decodeLast(item, into: &state)
            }
        }
        return state.projection
    }

    private static func decodeFirst(_ item: Codec.Metadata, into state: inout State) throws -> Bool {
        switch item.id {
        case MetadataID.assetKeysOrder:
            state.order = try stringList(item.value)
        case MetadataID.unusedChainIDs:
            state.unused = try stringList(item.value)
        case MetadataID.selectedCurrency:
            state.currency = try text(item.value, allowEmpty: false)
        case MetadataID.networkManagementFilter:
            state.networkFilter = try text(item.value, allowEmpty: true)
        case MetadataID.assetVisibility:
            state.visibility = try visibilityMap(item.value)
        default:
            return false
        }
        return true
    }

    private static func decodeLast(_ item: Codec.Metadata, into state: inout State) throws {
        switch item.id {
        case MetadataID.favoriteChainIDs:
            state.favorites = try stringList(item.value)
        case MetadataID.assetFilterOptions:
            let filters = try stringList(item.value)
            guard filters.count <= 32,
                  filters.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }) else {
                throw ProjectionError.invalidMetadata
            }
            state.assetFilters = filters
        case MetadataID.zeroBalanceAssetsHidden:
            state.zeroBalanceHidden = try boolean(item.value)
        case MetadataID.canExportEthereumMnemonic:
            state.canExportEthereumMnemonic = try boolean(item.value)
        case MetadataID.androidSelectedChainID:
            state.androidSelectedChainID = try text(item.value, allowEmpty: true)
        case MetadataID.androidChainSelectFilter:
            state.androidChainSelectFilter = try text(item.value, allowEmpty: true)
        case MetadataID.androidAssetRowPresentation:
            do {
                state.androidAssetRows = try Codec.decodeAssetRowPresentation(item.value)
            } catch {
                throw ProjectionError.invalidMetadata
            }
        default:
            throw ProjectionError.invalidMetadata
        }
    }

    private static func stringList(_ bytes: [UInt8]) throws -> [String] {
        var cursor = Codec.Cursor(bytes: bytes)
        defer { cursor.erase() }
        let count = try cursor.readUInt16()
        guard count <= Codec.maxChains else { throw ProjectionError.invalidMetadata }
        var result = [String]()
        result.reserveCapacity(count)
        for _ in 0 ..< count {
            try result.append(cursor.readText(allowEmpty: true))
        }
        guard cursor.isAtEnd else { throw ProjectionError.invalidMetadata }
        return result
    }

    private static func visibilityMap(_ bytes: [UInt8]) throws -> [Visibility] {
        var cursor = Codec.Cursor(bytes: bytes)
        defer { cursor.erase() }
        let count = try cursor.readUInt16()
        guard count <= Codec.maxChains else { throw ProjectionError.invalidMetadata }
        var result = [Visibility]()
        result.reserveCapacity(count)
        var previous: String?
        for _ in 0 ..< count {
            let assetID = try cursor.readText(allowEmpty: false)
            if let previous, !Codec.compareUTF8(previous, assetID) {
                throw ProjectionError.invalidMetadata
            }
            try result.append(Visibility(assetID: assetID, hidden: cursor.readBoolean()))
            previous = assetID
        }
        guard cursor.isAtEnd else { throw ProjectionError.invalidMetadata }
        return result
    }

    private static func text(_ bytes: [UInt8], allowEmpty: Bool) throws -> String {
        do {
            return try Codec.strictText(bytes, allowEmpty: allowEmpty)
        } catch {
            throw ProjectionError.invalidMetadata
        }
    }

    private static func boolean(_ bytes: [UInt8]) throws -> Bool {
        guard bytes.count == 1, let value = bytes.first, value <= 1 else {
            throw ProjectionError.invalidMetadata
        }
        return value == 1
    }
}

/// Android's selected chain and chain-selector filter have no equivalent iOS
/// wallet field. These read-only records describe a future wallet-owned
/// sidecar; they never write one or authorize receiving a wallet.
enum IOSForeignDisplayPrefs {
    private typealias Codec = IOSPortableWalletSemanticMaterial

    enum ProjectionError: Error, Equatable {
        case invalidWalletBinding
    }

    enum Destination: Equatable {
        case walletBoundSidecar
    }

    struct Candidate: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let walletIndex: Int
        let portableID: Data
        let destination: Destination
        let androidSelectedChainID: String?
        let androidChainSelectFilter: String?

        var description: String {
            "ForeignDisplayPreferences.Candidate(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    struct BoundRecord: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let destinationMetaID: String
        let portableID: Data
        let destination: Destination
        let androidSelectedChainID: String?
        let androidChainSelectFilter: String?

        var description: String {
            "ForeignDisplayPreferences.BoundRecord(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    static func project(
        walletIndex: Int,
        wallet: IOSPortableWalletSemanticMaterial.Wallet,
        metadata: IOSPortableReceiveMetadata.Projection?
    ) -> Candidate? {
        guard let metadata,
              metadata.androidSelectedChainID != nil || metadata.androidChainSelectFilter != nil else {
            return nil
        }
        return Candidate(
            walletIndex: walletIndex, portableID: Data(wallet.portableID),
            destination: .walletBoundSidecar,
            androidSelectedChainID: metadata.androidSelectedChainID,
            androidChainSelectFilter: metadata.androidChainSelectFilter
        )
    }

    /// Resolves a prospective sidecar against the journal's fresh iOS wallet
    /// IDs only after that journal proves the complete semantic cohort. This
    /// remains a read-only projection, not a durable install or readback.
    static func bind(
        _ candidates: [Candidate],
        semantic: Data,
        journal: IOSPortableWalletReceiveJournalRecord.Record
    ) throws -> [BoundRecord] {
        var snapshot: Codec.Snapshot
        do {
            try IOSPortableWalletReceiveJournalRecord.verifySemanticMaterial(semantic, for: journal)
            snapshot = try Codec.decode(semantic)
        } catch {
            throw ProjectionError.invalidWalletBinding
        }
        defer { snapshot.clearSecrets() }
        let expected = snapshot.wallets.enumerated().compactMap { index, wallet in
            project(
                walletIndex: index,
                wallet: wallet,
                metadata: try? IOSPortableReceiveMetadata.decode(wallet.metadata)
            )
        }
        guard candidates == expected else { throw ProjectionError.invalidWalletBinding }
        var seenWallets = Set<Int>()
        return try candidates.map { candidate in
            guard journal.wallets.indices.contains(candidate.walletIndex),
                  seenWallets.insert(candidate.walletIndex).inserted,
                  candidate.portableID == journal.wallets[candidate.walletIndex].portableID,
                  candidate.destination == .walletBoundSidecar,
                  candidate.androidSelectedChainID != nil || candidate.androidChainSelectFilter != nil else {
                throw ProjectionError.invalidWalletBinding
            }
            let wallet = journal.wallets[candidate.walletIndex]
            return BoundRecord(
                destinationMetaID: wallet.metaID, portableID: candidate.portableID,
                destination: .walletBoundSidecar,
                androidSelectedChainID: candidate.androidSelectedChainID,
                androidChainSelectFilter: candidate.androidChainSelectFilter
            )
        }
    }
}
