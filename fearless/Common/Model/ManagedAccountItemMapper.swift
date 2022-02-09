import Foundation
import RobinHood
import CoreData
import IrohaCrypto

enum ManagedAccountItemMapperError: Error {
    case invalidEntity
}

// TODO: remove
final class ManagedAccountItemMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = ManagedAccountItem
    typealias CoreDataEntity = CDMetaAccount

    var entityIdentifierFieldName: String {
        #keyPath(CoreDataEntity.metaId)
    }

    func populate(
        entity _: CDMetaAccount,
        from _: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {}

    func transform(entity: CDMetaAccount) throws -> DataProviderModel {
        guard
            let address = entity.metaId,
            let username = entity.name,
            let cryptoType = CryptoType(rawValue: UInt8(entity.substrateCryptoType)),
            let networkType = SNAddressType(rawValue: UInt8(0)),
            let publicKeyData = entity.substratePublicKey
        else {
            throw ManagedAccountItemMapperError.invalidEntity
        }

        return ManagedAccountItem(
            address: address,
            cryptoType: cryptoType,
            networkType: networkType,
            username: username,
            publicKeyData: publicKeyData,
            order: Int16(entity.order)
        )
    }
}
