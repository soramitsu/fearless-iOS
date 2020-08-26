import Foundation
import CoreData
import RobinHood
import IrohaCrypto

extension CDAccountItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: AccountItem.CodingKeys.self)

        let address = try container.decode(String.self, forKey: .address)

        let fetchRequest: NSFetchRequest<CDAccountItem> = CDAccountItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(CDAccountItem.identifier), address)
        var currentItem = try context.fetch(fetchRequest).first

        if currentItem == nil {
            fetchRequest.predicate = nil
            let sortDescriptor = NSSortDescriptor(key: #keyPath(CDAccountItem.order), ascending: false)
            fetchRequest.sortDescriptors = [sortDescriptor]
            fetchRequest.fetchLimit = 1

            currentItem = try context.fetch(fetchRequest).first
        }

        identifier = address
        username = try container.decode(String.self, forKey: .username)
        publicKey = try container.decode(Data.self, forKey: .publicKeyData)
        cryptoType = try container.decode(Int16.self, forKey: .cryptoType)
        networkType = try SS58AddressFactory().type(fromAddress: address).int16Value
        order = (currentItem?.order ?? 0) + 1
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AccountItem.CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .address)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(publicKey, forKey: .publicKeyData)
        try container.encode(cryptoType, forKey: .cryptoType)
    }
}
