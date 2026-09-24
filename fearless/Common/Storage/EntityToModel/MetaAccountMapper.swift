import Foundation
import RobinHood
import CoreData
import SSFModels
#if canImport(SSFAccountManagmentStorage)
    import SSFAccountManagmentStorage
#endif

enum MetaAccountMapperError: LocalizedError {
    case unsupportedWalletRecord
    case invalidWalletRecord
    case walletOrderOverflow

    var errorDescription: String? {
        switch self {
        case .unsupportedWalletRecord:
            return "The stored wallet does not contain the account fields supported by this app version"
        case .invalidWalletRecord:
            return "The stored wallet record is invalid"
        case .walletOrderOverflow:
            return "The wallet order cannot be incremented safely"
        }
    }
}

final class MetaAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMetaAccount.metaId) }

    typealias DataProviderModel = MetaAccountModel
    typealias CoreDataEntity = CDMetaAccount
}

extension MetaAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        var mappedAccount: DataProviderModel?

        // A generated Core Data getter may raise NSException when an old or
        // damaged row cannot materialize. Keep the complete read graph,
        // including every child relationship traversal, inside one Objective-C
        // exception boundary so startup receives a catchable Swift error.
        try SafeObjectiveCExceptionBoundary.perform {
            mappedAccount = try self.transformWithoutExceptionBoundary(
                entity: entity
            )
        }

        guard let mappedAccount else {
            throw MetaAccountMapperError.invalidWalletRecord
        }

        return mappedAccount
    }

    // Wallet validation remains one fail-closed mapping.
    // swiftlint:disable:next function_body_length
    private func transformWithoutExceptionBoundary(
        entity: CoreDataEntity
    ) throws -> DataProviderModel {
        guard
            let metaId = entity.metaId,
            !metaId.isEmpty,
            metaId == metaId.trimmingCharacters(in: .whitespacesAndNewlines),
            let name = entity.name,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw MetaAccountMapperError.invalidWalletRecord
        }

        let substrateAccountId: Data?
        let substratePublicKey: Data?
        let substrateCryptoType: CryptoType
        let legacyTonAccount: LegacyTonAccount?
        if let accountIdHex = entity.substrateAccountId, let publicKey = entity.substratePublicKey {
            guard !accountIdHex.isEmpty,
                  let cryptoType = CryptoType(rawValue: UInt8(truncatingIfNeeded: entity.substrateCryptoType)),
                  Int16(cryptoType.rawValue) == entity.substrateCryptoType,
                  publicKey.count == (cryptoType == .ecdsa ? 33 : 32)
            else { throw MetaAccountMapperError.invalidWalletRecord }
            let accountId = try Data(hexStringSSF: accountIdHex)
            guard accountId.count == 32 else { throw MetaAccountMapperError.invalidWalletRecord }
            substrateAccountId = accountId
            substratePublicKey = publicKey
            substrateCryptoType = cryptoType
            legacyTonAccount = nil
        } else {
            guard entity.substrateAccountId == nil, entity.substratePublicKey == nil else {
                throw MetaAccountMapperError.invalidWalletRecord
            }
            let tonColumnCount = ["tonAddress", "tonPublicKey", "tonContractVersion"].filter {
                entity.entity.propertiesByName[$0] != nil
            }.count
            guard tonColumnCount == 0 || tonColumnCount == 3 else {
                throw MetaAccountMapperError.unsupportedWalletRecord
            }
            let hasTonColumns = tonColumnCount == 3
            let version = hasTonColumns ? entity.value(forKey: "tonContractVersion") as? String : nil
            let serializedAddress = hasTonColumns ? entity.value(forKey: "tonAddress") as? Data : nil
            let tonPublicKey = hasTonColumns ? entity.value(forKey: "tonPublicKey") as? Data : nil
            if version != nil || serializedAddress != nil || tonPublicKey != nil {
                guard let version, version == "v4R2",
                      let serializedAddress, let tonPublicKey else {
                    throw MetaAccountMapperError.unsupportedWalletRecord
                }
                legacyTonAccount = try LegacyTonAccount(
                    serializedAddress: serializedAddress, publicKey: tonPublicKey, contractVersion: version
                )
            } else {
                // EVM-only wallets are valid roots on Android. The current Core Data
                // schema can represent them, but never mistake a partial or foreign
                // public identity for an installable iOS wallet.
                guard let addressHex = entity.ethereumAddress,
                      let ethereumPublicKey = entity.ethereumPublicKey else {
                    throw MetaAccountMapperError.unsupportedWalletRecord
                }
                let address = try Data(hexStringSSF: addressHex)
                guard address.count == 20,
                      (try? ethereumPublicKey.ethereumAddressFromPublicKey()) == address else {
                    throw MetaAccountMapperError.invalidWalletRecord
                }
                legacyTonAccount = nil
            }
            substrateAccountId = nil
            substratePublicKey = nil
            substrateCryptoType = .ed25519
        }

        let chainAccountEntities = entity.chainAccounts?.allObjects as? [CDChainAccount] ?? []
        var chainAccounts: [ChainAccountModel] = []
        var canonicalChainIds = Set<String>()
        for chainAccountEntity in chainAccountEntities {
            guard
                let accountIdHex = chainAccountEntity.accountId,
                let chainId = chainAccountEntity.chainId,
                !chainId.isEmpty,
                chainId == chainId.trimmingCharacters(in: .whitespacesAndNewlines),
                let publicKey = chainAccountEntity.publicKey,
                let cryptoType = CryptoType(
                    rawValue: UInt8(truncatingIfNeeded: chainAccountEntity.cryptoType)
                ),
                Int16(cryptoType.rawValue) == chainAccountEntity.cryptoType
            else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let accountId = try Data(hexStringSSF: accountIdHex)
            guard !accountId.isEmpty else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let expectedPublicKeyLength = cryptoType == .ecdsa ? 33 : 32
            guard publicKey.count == expectedPublicKeyLength else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let canonicalChainId =
                UniversalWalletChainAccountSupport.canonicalChainId(for: chainId)
            guard canonicalChainIds.insert(canonicalChainId).inserted else {
                // `chainAccounts` is stored as an unordered Core Data relationship. Allowing
                // two rows for one chain would make the selected account depend on fetch order.
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let storedEcosystem: String?
            if chainAccountEntity.entity.propertiesByName["ecosystem"] != nil {
                storedEcosystem = chainAccountEntity.value(forKey: "ecosystem") as? String
            } else {
                storedEcosystem = nil
            }

            let isEthereumBased =
                storedEcosystem == UniversalWalletEcosystem.evm.rawValue ||
                storedEcosystem == "ethereum" ||
                storedEcosystem == "ethereumBased" ||
                chainAccountEntity.ethereumBased

            chainAccounts.append(
                ChainAccountModel(
                    chainId: chainId,
                    accountId: accountId,
                    publicKey: publicKey,
                    cryptoType: cryptoType.rawValue,
                    ethereumBased: isEthereumBased
                )
            )
        }

        var selectedCurrency: Currency?
        if let currency = entity.selectedCurrency,
           let id = currency.id,
           let symbol = currency.symbol,
           let name = currency.name,
           let icon = currency.icon {
            selectedCurrency = Currency(
                id: id,
                symbol: symbol,
                name: name,
                icon: icon,
                isSelected: currency.isSelected
            )
        }

        let ethereumAddress = try entity.ethereumAddress.map {
            let address = try Data(hexStringSSF: $0)
            guard address.count == 20 else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            return address
        }

        if let ethereumPublicKey = entity.ethereumPublicKey,
           ethereumPublicKey.isEmpty {
            throw MetaAccountMapperError.invalidWalletRecord
        }

        // Read assetsVisibility relationship via KVC, but only if the property exists in the loaded model
        var assetsVisibility: [AssetVisibility] = []
        if entity.entity.propertiesByName["assetsVisibility"] != nil,
           let rel = (entity.value(forKey: "assetsVisibility") as? NSSet)?.allObjects as? [NSManagedObject] {
            assetsVisibility = rel.compactMap { obj in
                guard let assetId = obj.value(forKey: "assetId") as? String else { return nil }
                let hidden = (obj.value(forKey: "hidden") as? Bool) ?? false
                return AssetVisibility(assetId: assetId, hidden: hidden)
            }
        }
        // These are user preferences, not wallet identity. Decode each behind
        // its own exception boundary so one damaged archive cannot hide an
        // otherwise usable wallet or discard the other valid preferences.
        let assetKeysOrder: [String]? = try? SafeTransformableValueReader.read(
            from: entity,
            key: "assetKeysOrder"
        )
        let unusedChainIds: [String]? = try? SafeTransformableValueReader.read(
            from: entity,
            key: "unusedChainIds"
        )
        let favouriteChainIds: [String] =
            (try? SafeTransformableValueReader.read(
                from: entity,
                key: "favouriteChainIds"
            )) ?? []

        return DataProviderModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType.rawValue,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: entity.ethereumPublicKey,
            chainAccounts: Set(chainAccounts),
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: entity.canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency ?? Currency.defaultCurrency(),
            networkManagmentFilter: entity.networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: entity.hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        try populate(entity: entity, from: model, using: context, replaceChildrenExactly: false)
    }

    /// Explicit exact replacement for a future verified restore writer.
    /// Ordinary wallet saves retain their released merge behavior.
    func populateExactReplacement(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        try populate(entity: entity, from: model, using: context, replaceChildrenExactly: true)
    }

    private func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext,
        replaceChildrenExactly: Bool
    ) throws {
        guard (model.substrateAccountId == nil) == (model.substratePublicKey == nil),
              (model.ethereumAddress == nil) == (model.ethereumPublicKey == nil) else {
            throw MetaAccountMapperError.invalidWalletRecord
        }
        if model.substrateAccountId == nil, model.substratePublicKey == nil,
           model.legacyTonAccount == nil {
            guard let publicKey = model.ethereumPublicKey,
                  let address = model.ethereumAddress,
                  address.count == 20,
                  (try? publicKey.ethereumAddressFromPublicKey()) == address else {
                throw MetaAccountMapperError.invalidWalletRecord
            }
        }
        // Validate unordered child identities before changing the managed object. A model can
        // contain distinct `ChainAccountModel` values whose chain IDs are aliases of one chain.
        // Persisting both would make subsequent account selection depend on NSSet iteration order.
        try validateChainAccountsBeforeMutation(model.chainAccounts)
        let storedChainAccounts = entity.chainAccounts?.allObjects as? [CDChainAccount] ?? []
        try validateStoredChainAccountsBeforeMutation(storedChainAccounts)

        entity.metaId = model.metaId
        entity.name = model.name
        entity.substrateAccountId = model.substrateAccountId?.toHex()
        if model.substrateAccountId != nil {
            entity.substrateCryptoType = Int16(bitPattern: UInt16(model.substrateCryptoType))
        }
        try populateTonIdentity(
            model.legacyTonAccount, in: entity, replaceExactly: replaceChildrenExactly
        )
        entity.substratePublicKey = model.substratePublicKey
        entity.ethereumPublicKey = model.ethereumPublicKey
        entity.ethereumAddress = model.ethereumAddress?.toHex()
        entity.assetKeysOrder = model.assetKeysOrder as? NSArray
        entity.canExportEthereumMnemonic = model.canExportEthereumMnemonic
        entity.unusedChainIds = model.unusedChainIds as? NSArray
        entity.networkManagmentFilter = model.networkManagmentFilter
        entity.hasBackup = model.hasBackup
        entity.favouriteChainIds = model.favouriteChainIds as NSArray

        try replaceVisibilityRows(
            model.assetsVisibility, in: entity, using: context,
            replaceExactly: replaceChildrenExactly
        )
        if replaceChildrenExactly {
            try removeObsoleteChainRows(
                storedChainAccounts, keeping: model.chainAccounts,
                in: entity, using: context
            )
        }

        for chainAccount in model.chainAccounts {
            let canonicalChainId =
                UniversalWalletChainAccountSupport.canonicalChainId(for: chainAccount.chainId)
            var chainAccountEntity = entity.chainAccounts?.first {
                if let entity = $0 as? CDChainAccount,
                   let storedChainId = entity.chainId,
                   UniversalWalletChainAccountSupport.canonicalChainId(for: storedChainId) ==
                   canonicalChainId {
                    return true
                } else {
                    return false
                }
            } as? CDChainAccount

            if chainAccountEntity == nil {
                let newEntity = CDChainAccount(context: context)
                entity.addToChainAccounts(newEntity)
                chainAccountEntity = newEntity
            }

            chainAccountEntity?.accountId = chainAccount.accountId.toHex()
            chainAccountEntity?.chainId = chainAccount.chainId
            chainAccountEntity?.cryptoType = Int16(bitPattern: UInt16(chainAccount.cryptoType))
            chainAccountEntity?.publicKey = chainAccount.publicKey
            chainAccountEntity?.ethereumBased = chainAccount.ethereumBased

            if
                let chainAccountEntity,
                chainAccountEntity.entity.propertiesByName["ecosystem"] != nil,
                chainAccountEntity.value(forKey: "ecosystem") == nil {
                chainAccountEntity.setValue(
                    chainAccount.ethereumBased
                        ? UniversalWalletEcosystem.evm.rawValue
                        : UniversalWalletEcosystem.substrate.rawValue,
                    forKey: "ecosystem"
                )
            }
        }

        updatedEntityCurrency(for: entity, from: model, context: context)
    }

    private func populateTonIdentity(
        _ ton: LegacyTonAccount?, in entity: CDMetaAccount, replaceExactly: Bool
    ) throws {
        let columns = ["tonAddress", "tonPublicKey", "tonContractVersion"]
        let available = columns.filter { entity.entity.propertiesByName[$0] != nil }
        guard available.isEmpty || available.count == columns.count else {
            throw MetaAccountMapperError.unsupportedWalletRecord
        }
        if let ton {
            guard available.count == columns.count else {
                throw MetaAccountMapperError.unsupportedWalletRecord
            }
            entity.setValue(ton.serializedAddress, forKey: "tonAddress")
            entity.setValue(ton.publicKey, forKey: "tonPublicKey")
            entity.setValue(ton.contractVersion, forKey: "tonContractVersion")
        } else if replaceExactly, available.count == columns.count {
            // A replacement must not retain an earlier native TON identity.
            for column in columns {
                entity.setValue(nil, forKey: column)
            }
        }
    }

    private func replaceVisibilityRows(
        _ visibility: [AssetVisibility], in entity: CDMetaAccount,
        using context: NSManagedObjectContext, replaceExactly: Bool
    ) throws {
        guard entity.entity.propertiesByName["assetsVisibility"] != nil else {
            return
        }
        let relationSet = entity.mutableSetValue(forKey: "assetsVisibility")
        let wantedIDs = Set(visibility.map(\.assetId))
        guard wantedIDs.count == visibility.count else {
            throw MetaAccountMapperError.invalidWalletRecord
        }
        if replaceExactly {
            var storedIDs = Set<String>()
            for case let stored as NSManagedObject in relationSet.allObjects {
                guard let assetID = stored.value(forKey: "assetId") as? String,
                      storedIDs.insert(assetID).inserted else {
                    throw MetaAccountMapperError.invalidWalletRecord
                }
                if !wantedIDs.contains(assetID) {
                    relationSet.remove(stored)
                    context.delete(stored)
                }
            }
        }
        for item in visibility {
            let matching = relationSet.allObjects
                .compactMap { $0 as? NSManagedObject }
                .first { $0.value(forKey: "assetId") as? String == item.assetId }
            let row = matching ?? NSEntityDescription.insertNewObject(
                forEntityName: "CDAssetVisibility", into: context
            )
            if matching == nil {
                relationSet.add(row)
            }
            row.setValue(item.assetId, forKey: "assetId")
            row.setValue(item.hidden, forKey: "hidden")
        }
    }

    private func removeObsoleteChainRows(
        _ storedRows: [CDChainAccount], keeping accounts: Set<ChainAccountModel>,
        in entity: CDMetaAccount, using context: NSManagedObjectContext
    ) throws {
        // Core Data's cascade rule only applies when deleting the whole wallet.
        let wantedIDs = Set(accounts.map {
            UniversalWalletChainAccountSupport.canonicalChainId(for: $0.chainId)
        })
        for stored in storedRows {
            guard let chainID = stored.chainId else {
                throw MetaAccountMapperError.invalidWalletRecord
            }
            if !wantedIDs.contains(UniversalWalletChainAccountSupport.canonicalChainId(for: chainID)) {
                entity.mutableSetValue(forKey: "chainAccounts").remove(stored)
                context.delete(stored)
            }
        }
    }

    private func validateChainAccountsBeforeMutation(
        _ chainAccounts: Set<ChainAccountModel>
    ) throws {
        var canonicalChainIds = Set<String>()

        for chainAccount in chainAccounts {
            let chainId = chainAccount.chainId
            let cryptoType = CryptoType(rawValue: chainAccount.cryptoType)
            guard
                !chainId.isEmpty,
                chainId == chainId.trimmingCharacters(in: .whitespacesAndNewlines),
                !chainAccount.accountId.isEmpty,
                let cryptoType
            else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let expectedPublicKeyLength = cryptoType == .ecdsa ? 33 : 32
            guard chainAccount.publicKey.count == expectedPublicKeyLength else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let canonicalChainId =
                UniversalWalletChainAccountSupport.canonicalChainId(for: chainId)
            guard canonicalChainIds.insert(canonicalChainId).inserted else {
                throw MetaAccountMapperError.invalidWalletRecord
            }
        }
    }

    private func validateStoredChainAccountsBeforeMutation(
        _ chainAccounts: [CDChainAccount]
    ) throws {
        var canonicalChainIds = Set<String>()

        for chainAccount in chainAccounts {
            guard
                let accountIdHex = chainAccount.accountId,
                let chainId = chainAccount.chainId,
                !chainId.isEmpty,
                chainId == chainId.trimmingCharacters(in: .whitespacesAndNewlines),
                let publicKey = chainAccount.publicKey,
                let cryptoType = CryptoType(
                    rawValue: UInt8(truncatingIfNeeded: chainAccount.cryptoType)
                ),
                Int16(cryptoType.rawValue) == chainAccount.cryptoType
            else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let accountId = try Data(hexStringSSF: accountIdHex)
            let expectedPublicKeyLength = cryptoType == .ecdsa ? 33 : 32
            guard
                !accountId.isEmpty,
                publicKey.count == expectedPublicKeyLength
            else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let canonicalChainId =
                UniversalWalletChainAccountSupport.canonicalChainId(for: chainId)
            guard canonicalChainIds.insert(canonicalChainId).inserted else {
                throw MetaAccountMapperError.invalidWalletRecord
            }
        }
    }

    private func updatedEntityCurrency(
        for entity: CoreDataEntity,
        from model: DataProviderModel,
        context: NSManagedObjectContext
    ) {
        let currencyEntity = CDCurrency(context: context)
        currencyEntity.id = model.selectedCurrency.id
        currencyEntity.name = model.selectedCurrency.name
        currencyEntity.symbol = model.selectedCurrency.symbol
        currencyEntity.icon = model.selectedCurrency.icon
        currencyEntity.isSelected = model.selectedCurrency.isSelected ?? false

        entity.selectedCurrency = currencyEntity
    }
}

/// A selection-safe projection of a stored wallet. Unsupported or corrupt rows are represented
/// without manufacturing a `MetaAccountModel`; corrupt projections are strictly read-only.
enum MetaAccountSelectionRecordState: Equatable {
    case supported
    case unsupported
    case corrupt

    var allowsStoredRecordUpdates: Bool {
        self != .corrupt
    }
}

/// Raw persisted display choices that the app-local wallet model does not expose.
/// Retain unknown filter names so recovery cannot silently discard them.
struct PersistedWalletDisplayPreferences: Equatable {
    let assetFilterOptions: [String]?
    let zeroBalanceAssetsHidden: Bool
}

struct MetaAccountSelectionModel: Identifiable {
    let identifier: String
    let wallet: MetaAccountModel?
    let isSelected: Bool
    let order: UInt32
    let displayPreferences: PersistedWalletDisplayPreferences?
    let recordState: MetaAccountSelectionRecordState
    let updatesWalletPayload: Bool
    let updatesSelection: Bool
    let replacesWalletChildrenExactly: Bool

    init(
        identifier: String,
        wallet: MetaAccountModel?,
        isSelected: Bool,
        order: UInt32,
        displayPreferences: PersistedWalletDisplayPreferences? = nil,
        recordState: MetaAccountSelectionRecordState = .supported,
        updatesWalletPayload: Bool = false,
        updatesSelection: Bool = true,
        replacesWalletChildrenExactly: Bool = false
    ) {
        self.identifier = identifier
        self.wallet = wallet
        self.isSelected = isSelected
        self.order = order
        self.displayPreferences = displayPreferences
        self.recordState = recordState
        self.updatesWalletPayload = updatesWalletPayload
        self.updatesSelection = updatesSelection
        self.replacesWalletChildrenExactly = replacesWalletChildrenExactly
    }

    func replacingSelection(_ isSelected: Bool) -> MetaAccountSelectionModel {
        MetaAccountSelectionModel(
            identifier: identifier,
            wallet: wallet,
            isSelected: isSelected,
            order: order,
            displayPreferences: displayPreferences,
            recordState: recordState,
            updatesSelection: recordState.allowsStoredRecordUpdates
        )
    }
}

final class MetaAccountSelectionMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMetaAccount.metaId) }

    typealias DataProviderModel = MetaAccountSelectionModel
    typealias CoreDataEntity = CDMetaAccount

    private lazy var metaAccountMapper = MetaAccountMapper()
    private let captureDisplayPreferences: Bool

    init(captureDisplayPreferences: Bool = false) {
        self.captureDisplayPreferences = captureDisplayPreferences
    }

    private func quarantineIdentifier(for entity: CDMetaAccount) -> String {
        "fearless.quarantined-wallet:\(entity.objectID.uriRepresentation().absoluteString)"
    }
}

extension MetaAccountSelectionMapper: CoreDataMapperProtocol {
    func transform(entity: CDMetaAccount) throws -> MetaAccountSelectionModel {
        var mappedSelection: MetaAccountSelectionModel?

        // Selection is the first wallet read on startup. It must be protected
        // independently of MetaAccountMapper because corrupt rows may throw
        // while reading the identifier, selection flag, or ordering fields
        // before the nested wallet mapper is reached.
        try SafeObjectiveCExceptionBoundary.perform {
            mappedSelection = try self.transformWithoutExceptionBoundary(
                entity: entity
            )
        }

        guard let mappedSelection else {
            throw MetaAccountMapperError.invalidWalletRecord
        }

        return mappedSelection
    }

    private func transformWithoutExceptionBoundary(
        entity: CDMetaAccount
    ) throws -> MetaAccountSelectionModel {
        let storedIdentifier: String?
        let storedIsSelected: Bool
        let storedOrder: UInt32

        do {
            storedIdentifier = try SafeTransformableValueReader.read(
                from: entity,
                key: "metaId"
            )
            let selectedNumber: NSNumber? =
                try SafeTransformableValueReader.read(
                    from: entity,
                    key: "isSelected"
                )
            let orderNumber: NSNumber? =
                try SafeTransformableValueReader.read(
                    from: entity,
                    key: "order"
                )
            storedIsSelected = selectedNumber?.boolValue ?? false
            storedOrder = UInt32(
                bitPattern: orderNumber?.int32Value ?? 0
            )
        } catch {
            // The selection repository must keep mapping healthy siblings even
            // if this row cannot materialize its own projection fields.
            return MetaAccountSelectionModel(
                identifier: quarantineIdentifier(for: entity),
                wallet: nil,
                isSelected: false,
                order: 0,
                recordState: .corrupt
            )
        }

        let identifier = storedIdentifier.flatMap {
            let trimmedIdentifier = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !$0.isEmpty && $0 == trimmedIdentifier ? $0 : nil
        } ?? quarantineIdentifier(for: entity)
        let wallet: MetaAccountModel?
        let recordState: MetaAccountSelectionRecordState

        guard storedIdentifier.map({
            !$0.isEmpty &&
                $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }) == true
        else {
            wallet = nil
            recordState = .corrupt

            return MetaAccountSelectionModel(
                identifier: identifier,
                wallet: wallet,
                isSelected: storedIsSelected,
                order: storedOrder,
                recordState: recordState
            )
        }

        do {
            wallet = try metaAccountMapper.transform(entity: entity)
            recordState = .supported
        } catch MetaAccountMapperError.unsupportedWalletRecord {
            wallet = nil
            recordState = .unsupported
        } catch {
            // A damaged app-local row must not abort mapping of its healthy siblings.
            // Keep it as an immutable projection so no read or selection repair rewrites it.
            wallet = nil
            recordState = .corrupt
        }

        let displayPreferences: PersistedWalletDisplayPreferences?
        if captureDisplayPreferences, recordState == .supported {
            guard entity.entity.propertiesByName["assetFilterOptions"] != nil,
                  entity.entity.propertiesByName["zeroBalanceAssetsHidden"] != nil else {
                throw MetaAccountMapperError.unsupportedWalletRecord
            }
            let filters: [String]? = try SafeTransformableValueReader.read(
                from: entity, key: "assetFilterOptions"
            )
            let hidden: NSNumber? = try SafeTransformableValueReader.read(
                from: entity, key: "zeroBalanceAssetsHidden"
            )
            guard let hidden,
                  (filters?.count ?? 0) <= 32,
                  filters?.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }) != false else {
                throw MetaAccountMapperError.invalidWalletRecord
            }
            displayPreferences = PersistedWalletDisplayPreferences(
                assetFilterOptions: filters,
                zeroBalanceAssetsHidden: hidden.boolValue
            )
        } else {
            displayPreferences = nil
        }

        return MetaAccountSelectionModel(
            identifier: identifier,
            wallet: wallet,
            isSelected: storedIsSelected,
            order: storedOrder,
            displayPreferences: displayPreferences,
            recordState: recordState
        )
    }

    func populate(
        entity: CDMetaAccount,
        from model: MetaAccountSelectionModel,
        using context: NSManagedObjectContext
    ) throws {
        guard !model.replacesWalletChildrenExactly || model.updatesWalletPayload else {
            throw MetaAccountMapperError.invalidWalletRecord
        }
        if model.updatesWalletPayload {
            guard
                let wallet = model.wallet,
                wallet.metaId == model.identifier,
                entity.metaId == nil || entity.metaId == model.identifier
            else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let isNew = entity.metaId == nil

            if !isNew {
                do {
                    _ = try metaAccountMapper.transform(entity: entity)
                } catch {
                    throw SelectedWalletSettingsError.unsupportedWalletIdentifierConflict
                }
            }

            if model.replacesWalletChildrenExactly {
                try metaAccountMapper.populateExactReplacement(entity: entity, from: wallet, using: context)
            } else {
                try metaAccountMapper.populate(entity: entity, from: wallet, using: context)
            }
            try persistDisplayPreferences(model.displayPreferences, in: entity)

            if isNew {
                entity.order = try nextOrder(in: context)
            } else if model.order != ManagedMetaAccountModel.noOrder {
                entity.order = Int32(bitPattern: model.order)
            }
        } else {
            guard entity.metaId == model.identifier else {
                // A selection repair must never manufacture a partial wallet row.
                throw MetaAccountMapperError.invalidWalletRecord
            }

            guard
                !model.updatesSelection ||
                model.recordState.allowsStoredRecordUpdates
            else {
                // Corrupt projections are read-only, including their selection metadata.
                throw MetaAccountMapperError.invalidWalletRecord
            }
        }

        if model.updatesSelection {
            entity.isSelected = model.isSelected
        }
    }

    private func persistDisplayPreferences(
        _ preferences: PersistedWalletDisplayPreferences?, in entity: CDMetaAccount
    ) throws {
        guard let preferences else { return }
        guard entity.entity.propertiesByName["assetFilterOptions"] != nil,
              entity.entity.propertiesByName["zeroBalanceAssetsHidden"] != nil else {
            throw MetaAccountMapperError.unsupportedWalletRecord
        }
        guard (preferences.assetFilterOptions?.count ?? 0) <= 32,
              preferences.assetFilterOptions?.allSatisfy({
                  !$0.isEmpty && $0.utf8.count <= 128
              }) != false else {
            throw MetaAccountMapperError.invalidWalletRecord
        }
        try SafeObjectiveCExceptionBoundary.perform {
            entity.setValue(preferences.assetFilterOptions as NSArray?, forKey: "assetFilterOptions")
            entity.setValue(
                NSNumber(value: preferences.zeroBalanceAssetsHidden),
                forKey: "zeroBalanceAssetsHidden"
            )
        }
    }

    private func nextOrder(in context: NSManagedObjectContext) throws -> Int32 {
        let fetchRequest = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
        fetchRequest.includesPendingChanges = true
        fetchRequest.includesSubentities = false
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(CDMetaAccount.order), ascending: false)
        ]
        fetchRequest.predicate = NSPredicate(format: "%K > 0", #keyPath(CDMetaAccount.order))
        fetchRequest.fetchLimit = 1

        let lastOrder = try context.fetch(fetchRequest).first?.order ?? 0

        guard lastOrder < Int32.max else {
            throw MetaAccountMapperError.walletOrderOverflow
        }

        return lastOrder + 1
    }
}
