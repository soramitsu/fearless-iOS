#if canImport(SSFAssetManagmentStorage)
    import Foundation
    import CoreData
    import RobinHood
    import IrohaCrypto
    import SSFAssetManagmentStorage

    extension CDMetaAccount: CoreDataCodable {
        public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
            let model = try MetaAccountModel(from: decoder)
            try MetaAccountMapper().populate(entity: self, from: model, using: context)
            isSelected = false
            order = 0
        }

        public func encode(to encoder: Encoder) throws {
            let model = try MetaAccountMapper().transform(entity: self)
            try model.encode(to: encoder)
        }
    }
#endif
