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
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AccountItem.CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .address)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(publicKey, forKey: .publicKeyData)
        try container.encode(cryptoType, forKey: .cryptoType)
    }
}
