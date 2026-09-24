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

    /// The journal supplies fresh destination wallet IDs and the exact expected
    /// tag/digest inventory. No item is returned if a captured source is not a
    /// released iOS Keychain byte record or if any item is missing or altered.
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
                for slot in wallet.slots where slot.role == Codec.Role.auxiliarySource {
                    let item = try project(slot, wallet: wallet, metaID: binding.metaID)
                    guard tags.insert(item.tag).inserted else {
                        throw ProjectionError.duplicateDestinationTag
                    }
                    result.append(item)
                }
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
        return Item(tag: tag, value: value)
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
