import Foundation
import RobinHood
import CoreData

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

            let ethereumBased = chainAccontEntity.ethereumBased ?? false

            let accountId = try Data(hexString: chainAccontEntity.accountId!)
            return ChainAccountModel(
                chainId: chainAccontEntity.chainId!,
                accountId: accountId,
                publicKey: chainAccontEntity.publicKey!,
                cryptoType: UInt8(bitPattern: Int8(chainAccontEntity.cryptoType)),
                ethereumBased: ethereumBased
            )
        } ?? []

        let substrateAccountId = try Data(hexString: entity.substrateAccountId!)
        let ethereumAddress = try entity.ethereumAddress.map { try Data(hexString: $0) }

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
            assetIdsEnabled: entity.assetIdsEnabled as? [String],
            canExportEthereumMnemonic: entity.canExportEthereumMnemonic,
            unusedChainIds: entity.unusedChainIds as? [String]
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
        entity.assetIdsEnabled = model.assetIdsEnabled as? NSArray
        entity.assetKeysOrder = model.assetKeysOrder as? NSArray
        entity.canExportEthereumMnemonic = model.canExportEthereumMnemonic
        entity.unusedChainIds = model.unusedChainIds as? NSArray

        for chainAccount in model.chainAccounts {
            var chainAccountEntity = entity.chainAccounts?.first {
                if let entity = $0 as? CDChainAccount,
                   entity.chainId == chainAccount.chainId,
                   entity.accountId == chainAccount.accountId.toHex() {
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
    }
}
