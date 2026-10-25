/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreData
import Foundation

/**
 *  Enum is designed to define internal errors which can occur
 *  in ```CoreDataRepository```.
 */

public enum CoreDataRepositoryError: Error {
    /// Returned where there is no information about error.
    case undefined

    /// Returned when new entity can't be created.
    case creationFailed
}

/**
 *  Implementation of ```DataProviderRepositoryProtocol``` based on Core Data which manages list of
 *  objects of a particular type.
 *
 *  Repository requires an implementation of ```CoreDataServiceProtocol``` to request a context to save/fetch
 *  Core Data entities to/from persistent store. More precisely, repository operates two
 *  kind of models: swift model and NSManagedObject provided by the client as generic parameters.
 *  Repository converts swift model to NSManagedObject using mapper passed as a parameter during
 *  initialization and saves Core Data entity through context. And vice versa, repository converts
 *  NSManagedObject, fetched from the context, to swift model and returns to the client.
 *  Additionally, repository allows filtering and sorting fetched entities using ```NSPredicate``` and
 *  list of ```NSSortDescriptor``` provided during initialization.
 */

public final class CoreDataRepository<T: Identifiable, U: NSManagedObject> {
    public typealias Model = T

    /// Service which manages Core Data contexts and persistent storage.
    public let databaseService: CoreDataServiceProtocol

    /// Mapper to convert from swift model to Core Data NSManagedObject and back.
    public let dataMapper: AnyCoreDataMapper<T, U>

    /// Predicate to access only subset of objects.
    public let filter: NSPredicate?

    /// Descriptors to sort fetched NSManagedObject list.
    public let sortDescriptors: [NSSortDescriptor]

    /**
     *  Creates new Core Data repository object.
     *
     *  - parameters:
     *    - databaseService: Core Data persistent store and contexts manager.
     *    - mapper: Mapper converts from swift model to NSManagedObject and back.
     *    - filter: NSPredicate of the subset of objects to access. By default `nil` (all objects).
     *    - sortDescriptor: Descriptor to sort fetched objects. By default `nil`.
     */

    public init(
        databaseService: CoreDataServiceProtocol,
        mapper: AnyCoreDataMapper<T, U>,
        filter: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) {
        self.databaseService = databaseService
        dataMapper = mapper
        self.filter = filter
        self.sortDescriptors = sortDescriptors
    }

    func save(models: [Model], in context: NSManagedObjectContext) throws {
        for model in models {
            let entityName = String(describing: U.self)
            let fetchRequest = NSFetchRequest<U>(entityName: entityName)
            var predicate = NSPredicate(
                format: "%K == %@",
                dataMapper.entityIdentifierFieldName,
                model.identifier
            )

            if let filter = filter {
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filter, predicate])
            }

            fetchRequest.predicate = predicate
            fetchRequest.includesPropertyValues = false

            var optionalEntitity = try context.fetch(fetchRequest).first

            if optionalEntitity == nil {
                optionalEntitity = NSEntityDescription.insertNewObject(
                    forEntityName: entityName,
                    into: context
                ) as? U
            }

            guard let entity = optionalEntitity else {
                throw CoreDataRepositoryError.creationFailed
            }

            try dataMapper.populate(entity: entity, from: model, using: context)
        }
    }

    func saveBatch(models: [Model], in context: NSManagedObjectContext) throws {
        let objects = try models.map { try dataMapper.dict(for: $0) }
        let insertRequest = NSBatchInsertRequest(entity: U.entity(), objects: objects)
        insertRequest.resultType = .objectIDs
        let result = try context.execute(insertRequest) as? NSBatchInsertResult
        let objs = result?.result as? [NSManagedObjectID] ?? []
        let changes: [AnyHashable: Any] = [NSInsertedObjectIDsKey: objs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
    }

    func create(models: [Model], in context: NSManagedObjectContext) throws {
        for model in models {
            let entityName = String(describing: U.self)

            guard let entity = NSEntityDescription.insertNewObject(
                forEntityName: entityName,
                into: context
            ) as? U else {
                throw CoreDataRepositoryError.creationFailed
            }

            try dataMapper.populate(entity: entity, from: model, using: context)
        }
    }

    func delete(modelIds: [String], in context: NSManagedObjectContext) throws {
        for modelId in modelIds {
            let entityName = String(describing: U.self)
            let fetchRequest = NSFetchRequest<U>(entityName: entityName)
            fetchRequest.includesPropertyValues = false

            var predicate = NSPredicate(
                format: "%K == %@",
                dataMapper.entityIdentifierFieldName,
                modelId
            )

            if let filter = filter {
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filter, predicate])
            }

            fetchRequest.predicate = predicate

            if let entity = try context.fetch(fetchRequest).first {
                context.delete(entity)
            }
        }
    }

    func deleteAll(in context: NSManagedObjectContext) throws {
        let entityName = String(describing: U.self)
        let fetchRequest = NSFetchRequest<U>(entityName: entityName)
        fetchRequest.includesPropertyValues = false
        fetchRequest.predicate = filter

        let entities = try context.fetch(fetchRequest)

        for entity in entities {
            context.delete(entity)
        }
    }

    func call<T>(
        block: @escaping (T, Error?) -> Void,
        model: T,
        error: Error?,
        queue: DispatchQueue?
    ) {
        if let queue = queue {
            queue.async {
                block(model, error)
            }
        } else {
            block(model, error)
        }
    }

    func call(block: @escaping (Error?) -> Void, error: Error?, queue: DispatchQueue?) {
        if let queue = queue {
            queue.async {
                block(error)
            }
        } else {
            block(error)
        }
    }
}
