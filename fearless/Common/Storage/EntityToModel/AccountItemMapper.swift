import Foundation
import RobinHood
import CoreData
import IrohaCrypto

enum AccountItemMapperError: Error {
    case notSupported
}

final class AccountItemMapper: CoreDataMapperProtocol {
    let addressPrefix: UInt16
    let addressFactory: SS58AddressFactoryProtocol

    init(addressPrefix: UInt16, addressFactory: SS58AddressFactoryProtocol) {
        self.addressPrefix = addressPrefix
        self.addressFactory = addressFactory
    }

    typealias DataProviderModel = AccountItem
    typealias CoreDataEntity = CDMetaAccount

    var entityIdentifierFieldName: String { "metaId" }

    func transform(entity: CDMetaAccount) throws -> AccountItem {
        let substrateAccountId = try Data(hexString: entity.substrateAccountId!)
        let address = try addressFactory.address(fromAccountId: substrateAccountId, type: addressPrefix)
        let cryptoType = CryptoType(rawValue: UInt8(entity.substrateCryptoType))

        return AccountItem(
            address: address,
            cryptoType: cryptoType!,
            username: entity.name!,
            publicKeyData: entity.substratePublicKey!
        )
    }

    func populate(
        entity _: CoreDataEntity,
        from _: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        throw AccountItemMapperError.notSupported
    }
}
