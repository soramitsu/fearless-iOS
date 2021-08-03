import Foundation
import RobinHood
import CoreData

extension CDRuntimeMetadataItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let item = try RuntimeMetadataItem(from: decoder)

        identifier = item.chain
        version = Int32(bitPattern: item.version)
        txVersion = Int32(bitPattern: item.txVersion)
        metadata = item.metadata
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RuntimeMetadataItem.CodingKeys.self)

        try container.encode(identifier, forKey: .chain)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(UInt32(bitPattern: version), forKey: .version)
        try container.encode(UInt32(bitPattern: txVersion), forKey: .txVersion)
    }
}
