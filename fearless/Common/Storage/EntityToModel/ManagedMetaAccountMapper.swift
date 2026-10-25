import Foundation
import RobinHood
import CoreData
#if canImport(SSFAccountManagmentStorage)
    import SSFAccountManagmentStorage
#endif

final class ManagedMetaAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMetaAccount.metaId) }

    typealias DataProviderModel = ManagedMetaAccountModel
    typealias CoreDataEntity = CDMetaAccount

    private lazy var metaAccountMapper = MetaAccountMapper()
}

extension ManagedMetaAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CDMetaAccount) throws -> ManagedMetaAccountModel {
        let metaAccount = try metaAccountMapper.transform(entity: entity)

        return ManagedMetaAccountModel(
            info: metaAccount,
            isSelected: entity.isSelected,
            order: UInt32(bitPattern: entity.order)
        )
    }

    func populate(
        entity: CDMetaAccount,
        from model: ManagedMetaAccountModel,
        using context: NSManagedObjectContext
    ) throws {
        let isNew = entity.metaId == nil

        try metaAccountMapper.populate(entity: entity, from: model.info, using: context)

        entity.isSelected = model.isSelected

        let order: Int32

        if isNew {
            let fetchRequest = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            fetchRequest.includesPendingChanges = true
            fetchRequest.includesSubentities = false
            let sortDescriptor = NSSortDescriptor(key: #keyPath(CDMetaAccount.order), ascending: false)
            fetchRequest.sortDescriptors = [sortDescriptor]
            fetchRequest.predicate = NSPredicate(format: "%K > 0", #keyPath(CDMetaAccount.order))
            fetchRequest.fetchLimit = 1

            let maybeLastItem = try context.fetch(fetchRequest).first

            order = maybeLastItem?.order ?? 0

            guard order < Int32.max else {
                throw MetaAccountMapperError.walletOrderOverflow
            }

            entity.order = order + 1
        } else {
            entity.order = Int32(bitPattern: model.order)
        }
    }
}
