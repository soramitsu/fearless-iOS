import Foundation
import CoreData
import RobinHood

extension CDChain: CoreDataCodable {
    public func encode(to _: Encoder) throws {}
    public func populate(from _: Decoder, using _: NSManagedObjectContext) throws {}
}
