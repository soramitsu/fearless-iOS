import Foundation

extension IOSPortableWalletSemanticMaterial {
    static func ensure(_ condition: @autoclosure () -> Bool) throws {
        guard condition() else { throw CodecError.invalidMaterial }
    }

    static func strictText(_ bytes: [UInt8], allowEmpty: Bool) throws -> String {
        guard bytes.count <= maxText, allowEmpty || !bytes.isEmpty,
              let text = String(bytes: bytes, encoding: .utf8),
              Array(text.utf8) == bytes else {
            throw CodecError.invalidMaterial
        }
        return text
    }

    static func compareUTF8(_ left: String, _ right: String) -> Bool {
        Array(left.utf8).lexicographicallyPrecedes(Array(right.utf8))
    }

    static func validate(_ snapshot: Snapshot) throws {
        try ensure((1 ... maxWallets).contains(snapshot.wallets.count))
        try ensure(snapshot.wallets.indices.contains(snapshot.selectedIndex))
        var seenIDs = Set<Data>()
        for wallet in snapshot.wallets {
            try ensure(wallet.portableID.count == 16)
            try ensure(wallet.portableID.contains(where: { $0 != 0 }))
            try ensure(seenIDs.insert(Data(wallet.portableID)).inserted)
            try validateWallet(wallet)
        }
    }

    static func validateWallet(_ wallet: Wallet) throws {
        _ = try strictText(Array(wallet.name.utf8), allowEmpty: true)
        try ensure(wallet.metadata.count <= Int(MetadataID.androidChainSelectFilter))
        var lastMetadataID: UInt8 = 0
        for item in wallet.metadata {
            try ensure(item.id > lastMetadataID)
            try validateMetadata(item)
            lastMetadataID = item.id
        }

        try ensure((1 ... maxSlots).contains(wallet.slots.count))
        var previous: Slot?
        var chainCount = 0
        var favoriteCount = 0
        var auxiliaryCount = 0
        var watchCount = 0
        var materialCount = 0
        for slot in wallet.slots {
            try validateSlot(slot)
            if let prior = previous {
                let ordered = slot.role > prior.role ||
                    slot.role == prior.role && compareUTF8(prior.key, slot.key)
                try ensure(ordered)
            }
            previous = slot
            switch slot.role {
            case Role.chainAccount:
                chainCount += 1
            case Role.favoriteChain:
                favoriteCount += 1
            case Role.auxiliarySource:
                try ensure(slot.key == String(format: "%04x", auxiliaryCount))
                auxiliaryCount += 1
            case Role.watchIdentity:
                try ensure(slot.key == String(format: "%04x", watchCount))
                watchCount += 1
                materialCount += 1
            default:
                materialCount += 1
            }
        }
        try ensure(chainCount <= maxChains && favoriteCount <= maxChains)
        try ensure(auxiliaryCount <= maxAuxiliary && watchCount <= maxWatch)
        try ensure(materialCount > 0)
        try ensure(favoriteCount == 0 ||
            !wallet.metadata.contains(where: { $0.id == MetadataID.favoriteChainIDs }))
        for slot in wallet.slots where slot.role == Role.auxiliarySource {
            try validateAuxiliaryBinding(slot, slots: wallet.slots)
        }
    }

    static func validateMetadata(_ item: Metadata) throws {
        try ensure((MetadataID.assetKeysOrder ... MetadataID.androidChainSelectFilter).contains(item.id))
        try ensure(item.value.count <= maxSecret)
        switch item.id {
        case MetadataID.assetKeysOrder, MetadataID.unusedChainIDs,
             MetadataID.favoriteChainIDs, MetadataID.assetFilterOptions:
            try validateStringList(item.value)
        case MetadataID.selectedCurrency, MetadataID.networkManagementFilter,
             MetadataID.androidSelectedChainID, MetadataID.androidChainSelectFilter:
            _ = try strictText(item.value, allowEmpty: true)
        case MetadataID.assetVisibility:
            try validateVisibilityMap(item.value)
        case MetadataID.zeroBalanceAssetsHidden, MetadataID.canExportEthereumMnemonic:
            try validateBoolean(item.value)
        default:
            throw CodecError.invalidMaterial
        }
    }

    static func validateStringList(_ value: [UInt8]) throws {
        var cursor = Cursor(bytes: value)
        defer { cursor.erase() }
        let count = try cursor.readUInt16()
        try ensure(count <= maxChains)
        for _ in 0 ..< count {
            _ = try cursor.readText(allowEmpty: true)
        }
        try ensure(cursor.isAtEnd)
    }

    static func validateVisibilityMap(_ value: [UInt8]) throws {
        var cursor = Cursor(bytes: value)
        defer { cursor.erase() }
        let count = try cursor.readUInt16()
        try ensure(count <= maxChains)
        var previous: String?
        for _ in 0 ..< count {
            let key = try cursor.readText(allowEmpty: false)
            if let prior = previous {
                try ensure(compareUTF8(prior, key))
            }
            previous = key
            _ = try cursor.readBoolean()
        }
        try ensure(cursor.isAtEnd)
    }

    static func validateSlot(_ slot: Slot) throws {
        try ensure((Role.substrateRoot ... Role.watchIdentity).contains(slot.role))
        _ = try strictText(Array(slot.key.utf8), allowEmpty: slot.role <= Role.legacySubstrate)
        try ensure((slot.role <= Role.legacySubstrate) == slot.key.isEmpty)
        try ensure((1 ... 23).contains(slot.fields.count))
        let (allowed, required) = fieldSets(for: slot.role)
        var lastID: UInt8 = 0
        var present = Set<UInt8>()
        for field in slot.fields {
            try ensure(field.id > lastID && allowed.contains(field.id))
            try validateField(field, role: slot.role)
            present.insert(field.id)
            lastID = field.id
        }
        try ensure(required.isSubset(of: present))
        switch slot.role {
        case Role.tonRoot:
            try validateTonAddress(slot)
        case Role.legacySubstrate:
            try validateLegacyRecipe(slot, present: present)
        case Role.auxiliarySource:
            try validateAuxiliarySource(slot, present: present)
        case Role.watchIdentity:
            try validateWatchIdentity(slot, present: present)
        default:
            break
        }
    }

    static func fieldSets(for role: UInt8) -> (Set<UInt8>, Set<UInt8>) {
        switch role {
        case Role.substrateRoot:
            return ([1, 2, 3, 4, 5, 6, 7, 8, 11], [1, 2, 7, 8, 11])
        case Role.evmRoot:
            return ([1, 2, 3, 4, 5, 6, 7, 11], [1, 2, 7, 11])
        case Role.tonRoot:
            return ([1, 2, 4, 5, 7, 11, 12, 13, 14], [1, 2, 7, 11, 13, 14])
        case Role.legacySubstrate:
            return ([1, 2, 3, 4, 5, 6, 7, 8, 11, 12], [1, 2, 7, 8, 11])
        case Role.chainAccount:
            return ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [1, 2, 7, 8, 9, 10, 11])
        case Role.favoriteChain:
            return ([10], [10])
        case Role.auxiliarySource:
            return ([11, 15, 16, 17, 18, 19, 20, 21], [11, 15, 16, 17, 19, 20])
        case Role.watchIdentity:
            return ([1, 7, 8, 9, 10, 13, 14, 22, 23], [7, 22])
        default:
            return ([], [])
        }
    }

    // Keep the closed field-ID table visible alongside its byte constraints.
    // swiftlint:disable:next cyclomatic_complexity
    static func validateField(_ field: Field, role: UInt8) throws {
        let value = field.value
        switch field.id {
        case FieldID.publicKey:
            try ensure((1 ... maxPublic).contains(value.count))
        case FieldID.accountIDOrAddress:
            if role == Role.legacySubstrate {
                _ = try strictText(value, allowEmpty: false)
            } else if role == Role.tonRoot || role == Role.watchIdentity {
                try ensure((1 ... maxText).contains(value.count))
            } else {
                try ensure((1 ... maxPublic).contains(value.count))
            }
        case FieldID.privateKey, FieldID.nonce, FieldID.entropy, FieldID.seed, FieldID.sourceBytes:
            try ensure((1 ... maxSecret).contains(value.count))
        case FieldID.derivationPath, FieldID.chainName:
            _ = try strictText(value, allowEmpty: true)
        case FieldID.mnemonic, FieldID.bindingChainID, FieldID.watchChainID:
            _ = try strictText(value, allowEmpty: false)
        case FieldID.cryptoType:
            try validateNumber(value, range: 1 ... 3)
        case FieldID.initializedOrFavorite:
            try validateBoolean(value)
        case FieldID.sourceRecipe:
            let range: ClosedRange<UInt8> = role == Role.legacySubstrate ? 1 ... 5 :
                role == Role.auxiliarySource ? 0 ... 5 : 0 ... 0
            try validateNumber(value, range: range)
        case FieldID.tonContractVersion:
            try validateNumber(value, range: 0 ... 2)
        case FieldID.tonAddressEncoding, FieldID.sourcePlatform:
            try validateNumber(value, range: 1 ... 2)
        case FieldID.sourceSlotRole:
            try validateNumber(value, range: 1 ... 14)
        case FieldID.bindingKind:
            try validateNumber(value, range: 1 ... 5)
        case FieldID.sourceFormat, FieldID.watchEcosystem:
            try validateNumber(value, range: 1 ... 4)
        case FieldID.bindingAccountID:
            try ensure((1 ... maxPublic).contains(value.count))
        default:
            throw CodecError.invalidMaterial
        }
    }

    static func validateNumber(_ value: [UInt8], range: ClosedRange<UInt8>) throws {
        try ensure(value.count == 1)
        try ensure(range.contains(value[0]))
    }

    static func validateBoolean(_ value: [UInt8]) throws {
        try validateNumber(value, range: 0 ... 1)
    }

    static func validateLegacyRecipe(_ slot: Slot, present: Set<UInt8>) throws {
        let recipe = try slot.number(FieldID.sourceRecipe)
        let hasMnemonic = present.contains(FieldID.mnemonic)
        let hasEntropy = present.contains(FieldID.entropy)
        try ensure(hasMnemonic == hasEntropy)
        try ensure([1, 4].contains(recipe) == hasMnemonic)
        try ensure(![3, 5].contains(recipe) || !present.contains(FieldID.derivationPath))
        try ensure(recipe != 5 || !present.contains(FieldID.seed))
    }

    static func validateTonAddress(_ slot: Slot) throws {
        let contractVersion = try slot.number(FieldID.tonContractVersion)
        try ensure(contractVersion == 2)
        let address = try slot.value(FieldID.accountIDOrAddress)
        switch try slot.number(FieldID.tonAddressEncoding) {
        case 1:
            try ensure(address.count == 33)
        case 2:
            _ = try strictText(address, allowEmpty: false)
        default:
            throw CodecError.invalidMaterial
        }
    }

    static func validateWatchIdentity(_ slot: Slot, present: Set<UInt8>) throws {
        let ecosystem = try slot.number(FieldID.watchEcosystem)
        try ensure(present.contains(FieldID.watchChainID) == (ecosystem == 4))
        try ensure(present.contains(FieldID.cryptoType) == (ecosystem == 1 || ecosystem == 4))
        try ensure(present.contains(FieldID.tonContractVersion) == (ecosystem == 3))
        try ensure(present.contains(FieldID.tonAddressEncoding) == (ecosystem == 3))
        try ensure(![1, 4].contains(ecosystem) || present.contains(FieldID.publicKey))
        if ecosystem == 3 {
            try validateTonAddress(slot)
        } else {
            let address = try slot.value(FieldID.accountIDOrAddress)
            try ensure(address.count <= maxPublic)
        }
    }

    // Historical platform/slot/binding combinations are an explicit allowlist.
    // swiftlint:disable:next cyclomatic_complexity
    static func validateAuxiliarySource(_ slot: Slot, present: Set<UInt8>) throws {
        let platform = try slot.number(FieldID.sourcePlatform)
        let sourceRole = try slot.number(FieldID.sourceSlotRole)
        let binding = try slot.number(FieldID.bindingKind)
        let format = try slot.number(FieldID.sourceFormat)
        try ensure(present.contains(FieldID.bindingChainID) == (binding == 5))
        try ensure(present.contains(FieldID.bindingAccountID) == (binding == 5))

        let compatible: Bool
        switch platform {
        case 1:
            switch sourceRole {
            case 10: compatible = binding == 2 && format == 2
            case 11: compatible = binding == 2 && format == 4
            case 12: compatible = binding == 3 && format == 4
            case 13: compatible = binding == 4 && format == 4
            case 14: compatible = binding == 5 && format == 3
            default: compatible = false
            }
        case 2:
            if format != 1 {
                compatible = false
            } else {
                switch sourceRole {
                case 1, 5, 7: compatible = [1, 2, 5].contains(binding)
                case 2, 6, 8: compatible = [1, 3, 5].contains(binding)
                case 3: compatible = [1, 4, 5].contains(binding)
                case 4: compatible = (1 ... 5).contains(binding)
                case 9: compatible = binding == 1
                default: compatible = false
                }
            }
        default:
            compatible = false
        }
        try ensure(compatible)
    }

    static func validateAuxiliaryBinding(_ slot: Slot, slots: [Slot]) throws {
        let binding = try slot.number(FieldID.bindingKind)
        let corresponding: Bool
        switch binding {
        case 1:
            corresponding = true
        case 2:
            corresponding = slots.contains { [Role.substrateRoot, Role.legacySubstrate].contains($0.role) }
        case 3:
            corresponding = slots.contains { $0.role == Role.evmRoot }
        case 4:
            corresponding = slots.contains { $0.role == Role.tonRoot }
        case 5:
            let chainID = try strictText(slot.value(FieldID.bindingChainID), allowEmpty: false)
            let accountID = try slot.value(FieldID.bindingAccountID)
            corresponding = try slots.contains { candidate in
                guard candidate.role == Role.chainAccount, candidate.key == chainID else { return false }
                return try candidate.value(FieldID.accountIDOrAddress) == accountID
            }
        default:
            corresponding = false
        }
        try ensure(corresponding)
    }
}
