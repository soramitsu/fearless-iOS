import Foundation
import RobinHood
import CoreData
import SSFModels
#if canImport(SSFAccountManagmentStorage)
    import SSFAccountManagmentStorage
#endif

final class MetaAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMetaAccount.metaId) }

    typealias DataProviderModel = MetaAccountModel
    typealias CoreDataEntity = CDMetaAccount
}

extension MetaAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let chainAccountEntities = entity.chainAccounts?.allObjects as? [CDChainAccount] ?? []
        let chainAccounts: [ChainAccountModel] = try chainAccountEntities.compactMap { chainAccountEntity in
            guard
                let accountIdHex = chainAccountEntity.accountId,
                let chainId = chainAccountEntity.chainId,
                let publicKey = chainAccountEntity.publicKey
            else {
                return nil
            }

            let accountId = try Data(hexStringSSF: accountIdHex)

            return ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: UInt8(truncatingIfNeeded: chainAccountEntity.cryptoType),
                ecosystem: chainAccountEntity.ethereumBased ? .ethereum : .substrate
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

        let substrateAccountId = try Data(hexStringSSF: entity.substrateAccountId!)
        let ethereumAddress = try entity.ethereumAddress.map { try Data(hexStringSSF: $0) }
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
        var favouriteChainIds: [String] = []
        if let entityFavouriteChainIds = entity.favouriteChainIds {
            favouriteChainIds = (entityFavouriteChainIds as? [String]) ?? []
        }

        return DataProviderModel(
            metaId: entity.metaId!,
            name: entity.name!,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: UInt8(truncatingIfNeeded: entity.substrateCryptoType),
            substratePublicKey: entity.substratePublicKey!,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: entity.ethereumPublicKey,
            chainAccounts: Set(chainAccounts),
            assetKeysOrder: entity.assetKeysOrder as? [String],
            canExportEthereumMnemonic: entity.canExportEthereumMnemonic,
            unusedChainIds: entity.unusedChainIds as? [String],
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
            var chainAccountEntity = entity.chainAccounts?.first {
                if let entity = $0 as? CDChainAccount,
                   entity.chainId == chainAccount.chainId {
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
            chainAccountEntity?.ethereumBased = chainAccount.ecosystem == .ethereum
        }

        updatedEntityCurrency(for: entity, from: model, context: context)
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
