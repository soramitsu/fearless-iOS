import Foundation
import CoreData
import RobinHood

extension CDContactItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let contact = try ContactItem(from: decoder)

        identifier = contact.identifier
        peerAddress = contact.peerAddress
        peerName = contact.peerName
        targetAddress = contact.targetAddress
        updatedAt = contact.updatedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ContactItem.CodingKeys.self)

        try container.encodeIfPresent(peerAddress, forKey: .peerAddress)
        try container.encodeIfPresent(peerName, forKey: .peerName)
        try container.encodeIfPresent(targetAddress, forKey: .targetAddress)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
