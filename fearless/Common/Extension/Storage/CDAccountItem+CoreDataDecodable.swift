import Foundation
import CoreData
import RobinHood
import IrohaCrypto

extension CDAccountItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: AccountItem.CodingKeys.self)

        let address = try container.decode(String.self, forKey: .address)

        identifier = address
        username = try container.decode(String.self, forKey: .username)
        publicKey = try container.decode(Data.self, forKey: .publicKeyData)
        cryptoType = try container.decode(Int16.self, forKey: .cryptoType)
        networkType = try SS58AddressFactory().type(fromAddress: address).int16Value

        let fetchRequest: NSFetchRequest<CDAccountItem> = CDAccountItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(CDAccountItem.identifier), address)

        if let currentItem = try context.fetch(fetchRequest).first {
            order = currentItem.order
        } else {
            fetchRequest.predicate = nil
            let sortDescriptor = NSSortDescriptor(key: #keyPath(CDAccountItem.order), ascending: false)
            fetchRequest.sortDescriptors = [sortDescriptor]
            fetchRequest.fetchLimit = 1

            if let lastItem = try context.fetch(fetchRequest).first {
                order = lastItem.order + 1
            } else {
                order = 0
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AccountItem.CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .address)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(publicKey, forKey: .publicKeyData)
        try container.encode(cryptoType, forKey: .cryptoType)
    }
}
