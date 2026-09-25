import CryptoKit
import Foundation

/// Read-only after-image of released iOS Keychain items in one portable cohort.
/// This is not an install authorization: the caller must also prove every
/// signing identity and persist the complete wallet cohort transactionally.
enum IOSReceiveKeychainProjection {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    typealias Journal = IOSPortableWalletReceiveJournalRecord

    enum ProjectionError: Error, Equatable {
        case unsupportedSource
        case invalidSource
        case duplicateDestinationTag
        case missingRequiredKey
        case journalMismatch
    }

    struct Item: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let tag: String
        private(set) var value: Data

        /// Best-effort overwrite only; Swift copies may retain prior storage.
        mutating func clearSecret() {
            value.resetBytes(in: 0 ..< value.count)
        }

        var description: String {
            "IOSReceiveKeychainProjection.Item(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    /// The journal names candidate destination wallet IDs and the expected
    /// tag/digest inventory. The installer must prove the IDs and tags are
    /// unoccupied under its writer lock before staging any item. No item is
    /// returned if a captured source is unsupported, missing or altered.
    static func project(semantic encoded: Data, journal: Journal.Record) throws -> [Item] {
        do {
            try Journal.verifySemanticMaterial(encoded, for: journal)
        } catch {
            throw ProjectionError.journalMismatch
        }

        var snapshot = try Codec.decode(encoded)
        defer { snapshot.clearSecrets() }
        var result = [Item]()
        do {
            var tags = Set<String>()
            for (wallet, binding) in zip(snapshot.wallets, journal.wallets) {
                let walletItemIndexes = try projectWalletSources(
                    wallet, metaID: binding.metaID, tags: &tags, items: &result
                )
                try requireRootSources(
                    wallet, metaID: binding.metaID,
                    itemIndexes: walletItemIndexes, items: result
                )
                try requireChainExportSources(
                    wallet, metaID: binding.metaID,
                    itemIndexes: walletItemIndexes, items: result
                )
            }
            result.sort { $0.tag < $1.tag }
            let proofs = result.map { item in
                Journal.KeyProof(tag: item.tag, sha256: Data(SHA256.hash(data: item.value)))
            }
            guard proofs == journal.keys else { throw ProjectionError.journalMismatch }
            return result
        } catch {
            for index in result.indices {
                result[index].clearSecret()
            }
            throw error
        }
    }

    // The fixed Keychain role table is intentionally exhaustive.
    // swiftlint:disable:next cyclomatic_complexity
    private static func project(_ slot: Codec.Slot, wallet: Codec.Wallet, metaID: String) throws -> Item {
        guard try slot.number(FieldID.sourcePlatform) == 2,
              try slot.number(FieldID.sourceRecipe) == 0,
              try slot.number(FieldID.sourceFormat) == 1 else {
            throw ProjectionError.unsupportedSource
        }
        let sourceRole = try slot.number(FieldID.sourceSlotRole)
        let binding = try slot.number(FieldID.bindingKind)
        let accountID = try binding == 5 ? Data(slot.value(FieldID.bindingAccountID)) : nil
        let tag: String
        switch sourceRole {
        case 1:
            tag = KeystoreTagV2.substrateSecretKeyTagForMetaId(metaID, accountId: accountID)
        case 2:
            tag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaID, accountId: accountID)
        case 3:
            tag = KeystoreTagV2.tonSecretKeyTagForMetaId(metaID, accountId: accountID)
        case 4:
            tag = KeystoreTagV2.entropyTagForMetaId(metaID, accountId: accountID)
        case 5:
            tag = KeystoreTagV2.substrateSeedTagForMetaId(metaID, accountId: accountID)
        case 6:
            tag = KeystoreTagV2.ethereumSeedTagForMetaId(metaID, accountId: accountID)
        case 7:
            tag = KeystoreTagV2.substrateDerivationTagForMetaId(metaID, accountId: accountID)
        case 8:
            tag = KeystoreTagV2.ethereumDerivationTagForMetaId(metaID, accountId: accountID)
        case 9:
            tag = KeystoreTagV2.universalWalletSecretSourceTagForMetaId(metaID)
        default:
            throw ProjectionError.unsupportedSource
        }
        let value = try Data(slot.value(FieldID.sourceBytes))
        guard (1 ... 4096).contains(value.count), tag.utf8.count <= 512 else {
            throw ProjectionError.invalidSource
        }
        if sourceRole == 9,
           value != Data(UniversalWalletSeedBridge.contract.utf8) {
            throw ProjectionError.invalidSource
        }
        try validateSigningKeyAgreement(
            sourceRole: sourceRole, binding: binding, source: slot,
            wallet: wallet, value: value
        )
        if sourceRole == 4, binding == 1 {
            try validateWalletEntropyAgreement(wallet, value: value)
        }
        return Item(tag: tag, value: value)
    }

    private static func validateWalletEntropyAgreement(
        _ wallet: Codec.Wallet, value: Data
    ) throws {
        for primary in wallet.slots {
            let fieldID: UInt8
            switch primary.role {
            case Codec.Role.substrateRoot, Codec.Role.evmRoot:
                fieldID = FieldID.entropy
            case Codec.Role.tonRoot:
                fieldID = FieldID.mnemonic
            default:
                continue
            }
            if let recorded = primary.fields.first(where: { $0.id == fieldID }),
               Data(recorded.value) != value {
                throw ProjectionError.invalidSource
            }
        }
    }

    private static func requireRootSources(
        _ wallet: Codec.Wallet, metaID: String,
        itemIndexes: [String: Int], items: [Item]
    ) throws {
        for slot in wallet.slots {
            let required: String
            var exportSources = [(UInt8, String)]()
            switch slot.role {
            case Codec.Role.substrateRoot, Codec.Role.legacySubstrate:
                required = KeystoreTagV2.substrateSecretKeyTagForMetaId(metaID)
                exportSources = [
                    (FieldID.entropy, KeystoreTagV2.entropyTagForMetaId(metaID)),
                    (FieldID.seed, KeystoreTagV2.substrateSeedTagForMetaId(metaID)),
                    (FieldID.derivationPath, KeystoreTagV2.substrateDerivationTagForMetaId(metaID))
                ]
            case Codec.Role.evmRoot:
                required = KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaID)
                exportSources = [
                    (FieldID.entropy, KeystoreTagV2.entropyTagForMetaId(metaID)),
                    (FieldID.seed, KeystoreTagV2.ethereumSeedTagForMetaId(metaID)),
                    (FieldID.derivationPath, KeystoreTagV2.ethereumDerivationTagForMetaId(metaID))
                ]
            case Codec.Role.tonRoot:
                // The released native TON signer can recreate its key from
                // the captured phrase, which must also survive for export.
                required = KeystoreTagV2.entropyTagForMetaId(metaID)
                try requireTonPhrase(slot)
                exportSources = [(FieldID.mnemonic, required)]
            default:
                continue
            }
            guard itemIndexes[required] != nil else { throw ProjectionError.missingRequiredKey }
            for (fieldID, tag) in exportSources {
                guard let field = slot.fields.first(where: { $0.id == fieldID }) else { continue }
                guard let index = itemIndexes[tag] else { throw ProjectionError.missingRequiredKey }
                guard items[index].value == Data(field.value) else { throw ProjectionError.invalidSource }
            }
        }
    }

    private static func requireTonPhrase(_ slot: Codec.Slot) throws {
        guard slot.fields.contains(where: { $0.id == FieldID.mnemonic }) else {
            throw ProjectionError.missingRequiredKey
        }
    }

    private static func requireChainExportSources(
        _ wallet: Codec.Wallet, metaID: String,
        itemIndexes: [String: Int], items: [Item]
    ) throws {
        for chain in wallet.slots where chain.role == Codec.Role.chainAccount {
            let accountID = try Data(chain.value(FieldID.accountIDOrAddress))
            let sources: [(UInt8, [String])] = [
                (FieldID.entropy, [KeystoreTagV2.entropyTagForMetaId(metaID, accountId: accountID)]),
                (FieldID.seed, [
                    KeystoreTagV2.substrateSeedTagForMetaId(metaID, accountId: accountID),
                    KeystoreTagV2.ethereumSeedTagForMetaId(metaID, accountId: accountID)
                ]),
                (FieldID.derivationPath, [
                    KeystoreTagV2.substrateDerivationTagForMetaId(metaID, accountId: accountID),
                    KeystoreTagV2.ethereumDerivationTagForMetaId(metaID, accountId: accountID)
                ])
            ]
            for (fieldID, tags) in sources {
                guard let field = chain.fields.first(where: { $0.id == fieldID }) else { continue }
                let candidateIndexes = tags.compactMap { itemIndexes[$0] }
                guard !candidateIndexes.isEmpty else { throw ProjectionError.missingRequiredKey }
                guard candidateIndexes.contains(where: { items[$0].value.elementsEqual(field.value) }) else {
                    throw ProjectionError.invalidSource
                }
            }
        }
    }

    private static func validateSigningKeyAgreement(
        sourceRole: UInt8, binding: UInt8, source: Codec.Slot,
        wallet: Codec.Wallet, value: Data
    ) throws {
        let primary: Codec.Slot?
        switch (binding, sourceRole) {
        case (1, 1), (2, 1):
            primary = wallet.slots.first {
                $0.role == Codec.Role.substrateRoot || $0.role == Codec.Role.legacySubstrate
            }
        case (1, 2), (3, 2):
            primary = wallet.slots.first { $0.role == Codec.Role.evmRoot }
        case (1, 3), (4, 3):
            primary = wallet.slots.first { $0.role == Codec.Role.tonRoot }
        case (5, 1), (5, 2):
            let chainID = try Codec.strictText(source.value(FieldID.bindingChainID), allowEmpty: false)
            let accountID = try source.value(FieldID.bindingAccountID)
            primary = try wallet.slots.first { candidate in
                guard candidate.role == Codec.Role.chainAccount, candidate.key == chainID else {
                    return false
                }
                return try candidate.value(FieldID.accountIDOrAddress) == accountID
            }
            // Released Bitcoin and Taira signers derive from the root. An old
            // scoped Keychain value is retained as history, not as the primary
            // canonical signing key represented by this chain slot.
            let canonical = UniversalWalletChainAccountSupport.canonicalChainId(for: chainID)
            if [UniversalWalletRegistry.bitcoinMainnet.chainId,
                UniversalWalletRegistry.bitcoinTestnet.chainId,
                UniversalWalletRegistry.taira.chainId].contains(canonical) {
                return
            }
        default:
            return
        }
        if binding == 1, primary == nil {
            // A wallet-wide historical item without an active primary root is
            // retained, but it must not conflict with a root that does exist.
            return
        }
        guard let primary,
              try Data(primary.value(FieldID.privateKey)) == value else {
            throw ProjectionError.invalidSource
        }
    }
}

private extension IOSReceiveKeychainProjection {
    private struct SeenSource {
        let role: UInt8
        var chainIDs: Set<String>
    }

    /// One account ID can occur on several chain IDs while the released
    /// Keychain tag contains only that account ID. Keep every semantic chain
    /// binding but stage the identical underlying Keychain item only once.
    private static func projectWalletSources(
        _ wallet: Codec.Wallet, metaID: String,
        tags: inout Set<String>, items: inout [Item]
    ) throws -> [String: Int] {
        var indexes = [String: Int]()
        var seen = [String: SeenSource]()
        for slot in wallet.slots where slot.role == Codec.Role.auxiliarySource {
            let role = try slot.number(FieldID.sourceSlotRole)
            let binding = try slot.number(FieldID.bindingKind)
            let chainID = binding == 5
                ? try Codec.strictText(slot.value(FieldID.bindingChainID), allowEmpty: false) : nil
            var item = try project(slot, wallet: wallet, metaID: metaID)
            if let index = indexes[item.tag] {
                guard var prior = seen[item.tag], let chainID,
                      prior.role == role, !prior.chainIDs.isEmpty,
                      prior.chainIDs.insert(chainID).inserted,
                      items[index].value == item.value else {
                    item.clearSecret()
                    throw ProjectionError.duplicateDestinationTag
                }
                seen[item.tag] = prior
                item.clearSecret()
                continue
            }
            guard tags.insert(item.tag).inserted else {
                item.clearSecret()
                throw ProjectionError.duplicateDestinationTag
            }
            indexes[item.tag] = items.count
            seen[item.tag] = SeenSource(role: role, chainIDs: Set(chainID.map { [$0] } ?? []))
            items.append(item)
        }
        return indexes
    }
}
