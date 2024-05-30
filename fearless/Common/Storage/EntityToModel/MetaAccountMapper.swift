import Foundation
import RobinHood
import CoreData
import SSFAccountManagmentStorage

final class MetaAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMetaAccount.metaId) }

    typealias DataProviderModel = MetaAccountModel
    typealias CoreDataEntity = CDMetaAccount
}

extension MetaAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let chainAccounts: [ChainAccountModel] = try entity.chainAccounts?.compactMap { entity in
            guard let chainAccontEntity = entity as? CDChainAccount else {
                return nil
            }

            let ethereumBased = chainAccontEntity.ethereumBased

            let accountId = try Data(hexStringSSF: chainAccontEntity.accountId!)
            return ChainAccountModel(
                chainId: chainAccontEntity.chainId!,
                accountId: accountId,
                publicKey: chainAccontEntity.publicKey!,
                cryptoType: UInt8(bitPattern: Int8(chainAccontEntity.cryptoType)),
                ethereumBased: ethereumBased
            )
        } ?? []

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
        let assetFilterOptions = entity.assetFilterOptions as? [String]
        let assetsVisibility: [AssetVisibility]? = (entity.assetsVisibility?.allObjects as? [CDAssetVisibility])?.compactMap {
            guard let assetId = $0.assetId else {
                return nil
            }

            return AssetVisibility(assetId: assetId, hidden: $0.hidden)
        }
        var favouriteChainIds: [String] = []
        if let entityFavouriteChainIds = entity.favouriteChainIds {
            favouriteChainIds = (entityFavouriteChainIds as? [String]) ?? []
        }

        return DataProviderModel(
            metaId: entity.metaId!,
            name: entity.name!,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: UInt8(bitPattern: Int8(entity.substrateCryptoType)),
            substratePublicKey: entity.substratePublicKey!,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: entity.ethereumPublicKey,
            chainAccounts: Set(chainAccounts),
            assetKeysOrder: entity.assetKeysOrder as? [String],
            canExportEthereumMnemonic: entity.canExportEthereumMnemonic,
            unusedChainIds: entity.unusedChainIds as? [String],
            selectedCurrency: selectedCurrency ?? Currency.defaultCurrency(),
            networkManagmentFilter: entity.networkManagmentFilter,
            assetsVisibility: assetsVisibility ?? [],
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
        entity.favouriteChainIds = model.favouriteChainIds as? NSArray

        for assetVisibility in model.assetsVisibility {
            var assetVisibilityEntity = entity.assetsVisibility?.first { entity in
                (entity as? CDAssetVisibility)?.assetId == assetVisibility.assetId
            } as? CDAssetVisibility

            if assetVisibilityEntity == nil {
                let newEntity = CDAssetVisibility(context: context)
                entity.addToAssetsVisibility(newEntity)
                assetVisibilityEntity = newEntity
            }

            assetVisibilityEntity?.assetId = assetVisibility.assetId
            assetVisibilityEntity?.hidden = assetVisibility.hidden
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
            chainAccountEntity?.ethereumBased = chainAccount.ethereumBased
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
