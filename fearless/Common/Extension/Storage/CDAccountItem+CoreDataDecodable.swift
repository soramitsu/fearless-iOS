import Foundation
import CoreData
import RobinHood
import IrohaCrypto

// TODO: Fix logic
extension CDMetaAccount: CoreDataCodable {
    public func populate(from _: Decoder, using _: NSManagedObjectContext) throws {}

    public func encode(to _: Encoder) throws {}
}
