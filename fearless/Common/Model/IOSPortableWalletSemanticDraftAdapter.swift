import CryptoKit
import Foundation
import SSFModels

/// Converts a freshly verified local draft into FPWMSM01 plaintext. This has no
/// network or backup-completion call site. The future installer must independently
/// verify all keys and identities before accepting these bytes.
enum IOSPortableWalletSemanticDraftAdapter {
    typealias Codec = IOSPortableWalletSemanticMaterial
    typealias Role = IOSPortableWalletSemanticMaterial.Role
    typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    typealias MetadataID = IOSPortableWalletSemanticMaterial.MetadataID
    typealias DraftSlot = IOSPasskeyWalletMaterialDraft.SecretSlot

    enum AdapterError: Error, Equatable {
        case unrepresentableDraft
    }

    static func snapshot(from draft: IOSPasskeyWalletMaterialDraft) throws -> Codec.Snapshot {
        guard !draft.wallets.isEmpty, draft.wallets.count <= Codec.maxWallets else {
            throw AdapterError.unrepresentableDraft
        }
        var seen = Set<String>()
        var selectedIndex: Int?
        var wallets = [Codec.Wallet]()
        do {
            for (index, entry) in draft.wallets.enumerated() {
                guard seen.insert(entry.publicIdentity.metaId).inserted,
                      !entry.publicIdentity.metaId.isEmpty else {
                    throw AdapterError.unrepresentableDraft
                }
                if index > 0 {
                    let prior = draft.wallets[index - 1]
                    guard prior.order < entry.order ||
                        prior.order == entry.order && prior.publicIdentity.metaId < entry.publicIdentity.metaId else {
                        throw AdapterError.unrepresentableDraft
                    }
                }
                if entry.isSelected {
                    guard selectedIndex == nil else { throw AdapterError.unrepresentableDraft }
                    selectedIndex = index
                }
                wallets.append(try wallet(from: entry))
            }
            guard let selectedIndex else { throw AdapterError.unrepresentableDraft }
            let result = Codec.Snapshot(selectedIndex: selectedIndex, wallets: wallets)
            try Codec.validate(result)
            return result
        } catch {
            for index in wallets.indices { wallets[index].clearSecrets() }
            throw error
        }
    }

    static func encode(_ draft: IOSPasskeyWalletMaterialDraft) throws -> Data {
        var material = try snapshot(from: draft)
        defer { material.clearSecrets() }
        return try Codec.encode(material)
    }

    private static func wallet(from entry: IOSPasskeyWalletMaterialDraft.Wallet) throws -> Codec.Wallet {
        let identity = entry.publicIdentity
        var slots = [Codec.Slot]()
        do {
            if let substrate = try substrateRoot(from: entry) { slots.append(substrate) }
            if let ethereum = try evmRoot(from: entry) { slots.append(ethereum) }
            if let native = identity.legacyTonAccount {
                slots.append(try tonRoot(native, from: entry))
            }
            for account in identity.chainAccounts.sorted(by: chainOrder) {
                slots.append(try chainSlot(account, from: entry))
            }
            slots.append(contentsOf: try auxiliarySlots(from: entry))
            slots.sort { lhs, rhs in
                lhs.role < rhs.role || lhs.role == rhs.role && Codec.compareUTF8(lhs.key, rhs.key)
            }
            return Codec.Wallet(
                portableID: try portableID(for: identity.metaId),
                sourcePosition: entry.order,
                initialized: true,
                name: identity.name,
                metadata: try metadata(from: entry),
                slots: slots
            )
        } catch {
            for index in slots.indices { slots[index].clearSecrets() }
            throw error
        }
    }

    private static func auxiliarySlots(
        from entry: IOSPasskeyWalletMaterialDraft.Wallet
    ) throws -> [Codec.Slot] {
        var result = [Codec.Slot]()
        for (ordinal, source) in entry.slots.enumerated() {
            let binding: UInt8
            if let chainId = source.chainId, let accountID = source.accountId {
                guard entry.publicIdentity.chainAccounts.contains(where: {
                    $0.chainId == chainId && $0.accountId == accountID
                }) else { throw AdapterError.unrepresentableDraft }
                binding = 5
            } else if source.chainId != nil || source.accountId != nil {
                throw AdapterError.unrepresentableDraft
            } else {
                binding = rootBinding(for: source.role, wallet: entry.publicIdentity)
            }
            var fields = [
                field(FieldID.sourceRecipe, [0]),
                field(FieldID.sourcePlatform, [2]),
                field(FieldID.sourceSlotRole, [sourceRole(source.role)]),
                field(FieldID.bindingKind, [binding]),
                field(FieldID.sourceFormat, [1]),
                field(FieldID.sourceBytes, source.bytes)
            ]
            if binding == 5, let chainId = source.chainId, let accountID = source.accountId {
                fields.append(field(FieldID.bindingChainID, Data(chainId.utf8)))
                fields.append(field(FieldID.bindingAccountID, accountID))
            }
            result.append(slot(Role.auxiliarySource, String(format: "%04x", ordinal), fields))
        }
        return result
    }

    private static func rootBinding(for role: DraftSlot.Role, wallet: MetaAccountModel) -> UInt8 {
        switch role {
        case .substrateSecret, .substrateSeed, .substrateDerivation:
            return wallet.substratePublicKey == nil ? 1 : 2
        case .ethereumSecret, .ethereumSeed, .ethereumDerivation:
            return wallet.ethereumPublicKey == nil ? 1 : 3
        case .tonSecret:
            return wallet.legacyTonAccount == nil ? 1 : 4
        case .entropy, .universalWalletSource:
            return 1
        }
    }

    private static func sourceRole(_ role: DraftSlot.Role) -> UInt8 {
        switch role {
        case .substrateSecret: return 1
        case .ethereumSecret: return 2
        case .tonSecret: return 3
        case .entropy: return 4
        case .substrateSeed: return 5
        case .ethereumSeed: return 6
        case .substrateDerivation: return 7
        case .ethereumDerivation: return 8
        case .universalWalletSource: return 9
        }
    }
}

extension IOSPortableWalletSemanticDraftAdapter {
    static func portableID(for metaID: String) throws -> [UInt8] {
        let identifier = Array(metaID.utf8)
        guard !identifier.isEmpty, identifier.count <= Codec.maxText else {
            throw AdapterError.unrepresentableDraft
        }
        // Domain separation prevents source IDs from being confused with keys
        // or Android's durable integer identifiers. The installer must keep
        // this portable ID when importing onto another platform.
        let domain = Data("FPWMSM01:iOS:meta-id:v1".utf8)
        let count = Data([UInt8(identifier.count >> 8), UInt8(identifier.count & 0xFF)])
        return Array(SHA256.hash(data: domain + count + Data(identifier)).prefix(16))
    }

    static func cryptoType(_ native: UInt8) throws -> UInt8 {
        guard let type = CryptoType(rawValue: native) else {
            throw AdapterError.unrepresentableDraft
        }
        switch type {
        case .sr25519: return 1
        case .ed25519: return 2
        case .ecdsa: return 3
        }
    }

    static func chainOrder(_ lhs: ChainAccountModel, _ rhs: ChainAccountModel) -> Bool {
        if lhs.chainId != rhs.chainId { return Codec.compareUTF8(lhs.chainId, rhs.chainId) }
        return lhs.accountId.lexicographicallyPrecedes(rhs.accountId)
    }

    static func value(
        _ role: DraftSlot.Role,
        in entry: IOSPasskeyWalletMaterialDraft.Wallet,
        chainId: String? = nil,
        accountID: Data? = nil
    ) -> Data? {
        entry.slots.first {
            $0.role == role && $0.chainId == chainId && $0.accountId == accountID
        }?.bytes
    }

    static func required(
        _ role: DraftSlot.Role,
        in entry: IOSPasskeyWalletMaterialDraft.Wallet
    ) throws -> Data {
        guard let bytes = value(role, in: entry), !bytes.isEmpty else {
            throw AdapterError.unrepresentableDraft
        }
        return bytes
    }

    static func append(
        _ role: DraftSlot.Role,
        fieldID: UInt8,
        from entry: IOSPasskeyWalletMaterialDraft.Wallet,
        to fields: inout [Codec.Field],
        chainId: String? = nil,
        accountID: Data? = nil
    ) {
        if let bytes = value(role, in: entry, chainId: chainId, accountID: accountID) {
            fields.append(field(fieldID, bytes))
        }
    }

    static func field(_ id: UInt8, _ value: Data) -> Codec.Field {
        Codec.Field(id: id, value: Array(value))
    }

    static func field(_ id: UInt8, _ value: [UInt8]) -> Codec.Field {
        Codec.Field(id: id, value: value)
    }

    static func slot(_ role: UInt8, _ key: String, _ fields: [Codec.Field]) -> Codec.Slot {
        Codec.Slot(role: role, key: key, fields: fields.sorted { $0.id < $1.id })
    }

    static func metadata(from entry: IOSPasskeyWalletMaterialDraft.Wallet) throws -> [Codec.Metadata] {
        let identity = entry.publicIdentity
        var values = [Codec.Metadata]()
        if let order = identity.assetKeysOrder {
            values.append(Codec.Metadata(id: MetadataID.assetKeysOrder, value: try stringList(order)))
        }
        if let unused = identity.unusedChainIds {
            values.append(Codec.Metadata(id: MetadataID.unusedChainIDs, value: try stringList(unused)))
        }
        guard !identity.selectedCurrency.id.isEmpty else { throw AdapterError.unrepresentableDraft }
        values.append(Codec.Metadata(
            id: MetadataID.selectedCurrency, value: Array(identity.selectedCurrency.id.utf8)
        ))
        if let filter = identity.networkManagmentFilter {
            values.append(Codec.Metadata(id: MetadataID.networkManagementFilter, value: Array(filter.utf8)))
        }
        values.append(Codec.Metadata(
            id: MetadataID.assetVisibility, value: try visibilityMap(identity.assetsVisibility)
        ))
        values.append(Codec.Metadata(
            id: MetadataID.favoriteChainIDs, value: try stringList(identity.favouriteChainIds)
        ))
        if let filters = entry.displayPreferences.assetFilterOptions {
            values.append(Codec.Metadata(id: MetadataID.assetFilterOptions, value: try stringList(filters)))
        }
        values.append(Codec.Metadata(
            id: MetadataID.zeroBalanceAssetsHidden,
            value: [entry.displayPreferences.zeroBalanceAssetsHidden ? 1 : 0]
        ))
        values.append(Codec.Metadata(
            id: MetadataID.canExportEthereumMnemonic,
            value: [identity.canExportEthereumMnemonic ? 1 : 0]
        ))
        return values
    }

    static func stringList(_ values: [String]) throws -> [UInt8] {
        guard values.count <= Codec.maxChains else { throw AdapterError.unrepresentableDraft }
        var writer = Codec.Writer()
        defer { writer.erase() }
        try writer.writeUInt16(values.count)
        for value in values { try writer.writeText(value) }
        return writer.bytes
    }

    static func visibilityMap(_ values: [AssetVisibility]) throws -> [UInt8] {
        guard values.count <= Codec.maxChains else { throw AdapterError.unrepresentableDraft }
        let ordered = values.sorted { Codec.compareUTF8($0.assetId, $1.assetId) }
        var writer = Codec.Writer()
        defer { writer.erase() }
        try writer.writeUInt16(ordered.count)
        var previous: String?
        for value in ordered {
            guard !value.assetId.isEmpty, previous != value.assetId else {
                throw AdapterError.unrepresentableDraft
            }
            try writer.writeText(value.assetId)
            try writer.write(value.hidden ? 1 : 0)
            previous = value.assetId
        }
        return writer.bytes
    }
}
