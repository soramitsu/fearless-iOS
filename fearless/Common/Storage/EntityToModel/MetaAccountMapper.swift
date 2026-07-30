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

        guard
            let substrateAccountIdHex = entity.substrateAccountId,
            let substratePublicKey = entity.substratePublicKey
        else {
            throw MetaAccountMapperError.unsupportedWalletRecord
        }

        guard
            !substrateAccountIdHex.isEmpty,
            let substrateCryptoType = CryptoType(
                rawValue: UInt8(truncatingIfNeeded: entity.substrateCryptoType)
            ),
            Int16(substrateCryptoType.rawValue) == entity.substrateCryptoType
        else {
            throw MetaAccountMapperError.invalidWalletRecord
        }

        let expectedSubstratePublicKeyLength = substrateCryptoType == .ecdsa ? 33 : 32
        guard substratePublicKey.count == expectedSubstratePublicKeyLength else {
            throw MetaAccountMapperError.invalidWalletRecord
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

        let substrateAccountId = try Data(hexStringSSF: substrateAccountIdHex)
        guard substrateAccountId.count == 32 else {
            throw MetaAccountMapperError.invalidWalletRecord
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
            favouriteChainIds: favouriteChainIds
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        // Validate unordered child identities before changing the managed object. A model can
        // contain distinct `ChainAccountModel` values whose chain IDs are aliases of one chain.
        // Persisting both would make subsequent account selection depend on NSSet iteration order.
        try validateChainAccountsBeforeMutation(model.chainAccounts)
        let storedChainAccounts = entity.chainAccounts?.allObjects as? [CDChainAccount] ?? []
        try validateStoredChainAccountsBeforeMutation(storedChainAccounts)

        entity.metaId = model.metaId
        entity.name = model.name
        entity.substrateAccountId = model.substrateAccountId.toHex()
        entity.substrateCryptoType = Int16(bitPattern: UInt16(model.substrateCryptoType))
        entity.substratePublicKey = model.substratePublicKey
        entity.ethereumPublicKey = model.ethereumPublicKey
        entity.ethereumAddress = model.ethereumAddress?.toHex()
        entity.assetKeysOrder = model.assetKeysOrder as? NSArray
        entity.canExportEthereumMnemonic = model.canExportEthereumMnemonic
        entity.unusedChainIds = model.unusedChainIds as? NSArray
        entity.networkManagmentFilter = model.networkManagmentFilter
        entity.hasBackup = model.hasBackup
        entity.favouriteChainIds = model.favouriteChainIds as NSArray

        // Persist assetsVisibility via KVC/entity name when the relationship is available in the model
        if entity.entity.propertiesByName["assetsVisibility"] != nil {
            let relationSet = entity.mutableSetValue(forKey: "assetsVisibility")
            for assetVisibility in model.assetsVisibility {
                var match: NSManagedObject?
                for case let obj as NSManagedObject in relationSet {
                    if let assetId = obj.value(forKey: "assetId") as? String, assetId == assetVisibility.assetId {
                        match = obj
                        break
                    }
                }
                if match == nil {
                    let newObj = NSEntityDescription.insertNewObject(forEntityName: "CDAssetVisibility", into: context)
                    relationSet.add(newObj)
                    match = newObj
                }
                match?.setValue(assetVisibility.assetId, forKey: "assetId")
                match?.setValue(assetVisibility.hidden, forKey: "hidden")
            }
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

struct MetaAccountSelectionModel: Identifiable {
    let identifier: String
    let wallet: MetaAccountModel?
    let isSelected: Bool
    let order: UInt32
    let recordState: MetaAccountSelectionRecordState
    let updatesWalletPayload: Bool
    let updatesSelection: Bool

    init(
        identifier: String,
        wallet: MetaAccountModel?,
        isSelected: Bool,
        order: UInt32,
        recordState: MetaAccountSelectionRecordState = .supported,
        updatesWalletPayload: Bool = false,
        updatesSelection: Bool = true
    ) {
        self.identifier = identifier
        self.wallet = wallet
        self.isSelected = isSelected
        self.order = order
        self.recordState = recordState
        self.updatesWalletPayload = updatesWalletPayload
        self.updatesSelection = updatesSelection
    }

    func replacingSelection(_ isSelected: Bool) -> MetaAccountSelectionModel {
        MetaAccountSelectionModel(
            identifier: identifier,
            wallet: wallet,
            isSelected: isSelected,
            order: order,
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

        return MetaAccountSelectionModel(
            identifier: identifier,
            wallet: wallet,
            isSelected: storedIsSelected,
            order: storedOrder,
            recordState: recordState
        )
    }

    func populate(
        entity: CDMetaAccount,
        from model: MetaAccountSelectionModel,
        using context: NSManagedObjectContext
    ) throws {
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

            try metaAccountMapper.populate(entity: entity, from: wallet, using: context)

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
