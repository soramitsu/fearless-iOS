/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreData
import Foundation

extension CoreDataRepository {
    func fetch(
        by modelIdsClosure: @escaping () throws -> [String],
        options: RepositoryFetchOptions,
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping ([Model]?, Error?) -> Void
    ) {
        databaseService.performAsync { [weak self] optionalContext, optionalError in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    let modelIds = try modelIdsClosure()
                    let predicates = modelIds.compactMap {
                        NSPredicate(
                            format: "%K BEGINSWITH[cd] %@",
                            strongSelf.dataMapper.entityIdentifierFieldName,
                            $0
                        )
                    }
                    
                    var predicate: NSPredicate? = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

                    if let filter = strongSelf.filter {
                        predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                            filter
                        ] + predicates)
                    }

                    fetchRequest.predicate = predicate

                    fetchRequest.includesPropertyValues = options.includesProperties
                    fetchRequest.includesSubentities = options.includesSubentities

                    let entities = try context.fetch(fetchRequest)
                    let models = try entities
                        .map { try strongSelf.dataMapper.transform(entity: $0) }

                    strongSelf.call(block: block, model: models, error: nil, queue: queue)
                } catch {
                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    func fetch(
        by modelIdClosure: @escaping () throws -> String,
        options: RepositoryFetchOptions,
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping (Model?, Error?) -> Void
    ) {
        databaseService.performAsync { [weak self] optionalContext, optionalError in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    let modelId = try modelIdClosure()
                    var predicate = NSPredicate(
                        format: "%K == %@",
                        strongSelf.dataMapper.entityIdentifierFieldName,
                        modelId
                    )

                    if let filter = strongSelf.filter {
                        predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                            filter,
                            predicate,
                        ])
                    }

                    fetchRequest.predicate = predicate

                    fetchRequest.includesPropertyValues = options.includesProperties
                    fetchRequest.includesSubentities = options.includesSubentities

                    let entities = try context.fetch(fetchRequest)

                    if let entity = entities.first {
                        let model = try strongSelf.dataMapper.transform(entity: entity)

                        strongSelf.call(block: block, model: model, error: nil, queue: queue)
                    } else {
                        strongSelf.call(block: block, model: nil, error: nil, queue: queue)
                    }
                } catch {
                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    func fetchAll(
        with options: RepositoryFetchOptions,
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping ([Model]?, Error?) -> Void
    ) {
        databaseService.performAsync { [weak self] optionalContext, optionalError in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    fetchRequest.predicate = strongSelf.filter

                    if !strongSelf.sortDescriptors.isEmpty {
                        fetchRequest.sortDescriptors = strongSelf.sortDescriptors
                    }

                    fetchRequest.includesPropertyValues = options.includesProperties
                    fetchRequest.includesSubentities = options.includesSubentities

                    let entities = try context.fetch(fetchRequest)
                    let models = try entities
                        .map { try strongSelf.dataMapper.transform(entity: $0) }

                    strongSelf.call(block: block, model: models, error: nil, queue: queue)

                } catch {
                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    func fetch(
        request: RepositorySliceRequest,
        options: RepositoryFetchOptions,
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping ([Model]?, Error?) -> Void
    ) {
        databaseService.performAsync { [weak self] optionalContext, optionalError in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    fetchRequest.predicate = strongSelf.filter
                    fetchRequest.fetchOffset = request.offset
                    fetchRequest.fetchLimit = request.count

                    var sortDescriptors = strongSelf.sortDescriptors

                    if request.reversed {
                        sortDescriptors = sortDescriptors.compactMap {
                            $0.reversedSortDescriptor as? NSSortDescriptor
                        }
                    }

                    if !sortDescriptors.isEmpty {
                        fetchRequest.sortDescriptors = sortDescriptors
                    }

                    fetchRequest.includesPropertyValues = options.includesProperties
                    fetchRequest.includesSubentities = options.includesSubentities

                    let entities = try context.fetch(fetchRequest)
                    let models = try entities
                        .map { try strongSelf.dataMapper.transform(entity: $0) }

                    strongSelf.call(block: block, model: models, error: nil, queue: queue)

                } catch {
                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    func save(
        updating updatedModels: [Model],
        deleting deletedIds: [String],
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping (Error?) -> Void
    ) {
        databaseService.performAsync { optionalContext, optionalError in

            if let context = optionalContext {
                do {
                    try self.save(models: updatedModels, in: context)

                    try self.delete(modelIds: deletedIds, in: context)

                    try context.save()

                    self.call(block: block, error: nil, queue: queue)

                } catch {
                    context.rollback()

                    self.call(block: block, error: error, queue: queue)
                }
            } else {
                self.call(block: block, error: optionalError, queue: queue)
            }
        }
    }

    func saveBatch(
        updating updatedModels: [Model],
        deleting deletedIds: [String],
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping (Error?) -> Void
    ) {
        databaseService.performAsync { optionalContext, optionalError in

            guard let context = optionalContext else {
                self.call(block: block, error: optionalError, queue: queue)
                return
            }

            do {
                try self.saveBatch(models: updatedModels, in: context)

                try self.delete(modelIds: deletedIds, in: context)

                try context.save()

                self.call(block: block, error: nil, queue: queue)

            } catch {
                context.rollback()

                self.call(block: block, error: error, queue: queue)
            }
        }
    }

    func replace(
        with newModels: [Model],
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping (Error?) -> Void
    ) {
        databaseService.performAsync { optionalContext, optionalError in
            if let context = optionalContext {
                do {
                    try self.deleteAll(in: context)
                    try self.create(models: newModels, in: context)

                    try context.save()

                    self.call(block: block, error: nil, queue: queue)

                } catch {
                    context.rollback()

                    self.call(block: block, error: error, queue: queue)
                }
            } else {
                self.call(block: block, error: optionalError, queue: queue)
            }
        }
    }

    func fetchCount(
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping (Int?, Error?) -> Void
    ) {
        databaseService.performAsync { [weak self] optionalContext, optionalError in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    fetchRequest.predicate = strongSelf.filter

                    let count = try context.count(for: fetchRequest)

                    strongSelf.call(block: block, model: count, error: nil, queue: queue)

                } catch {
                    context.rollback()

                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    func deleteAll(
        runCompletionIn queue: DispatchQueue?,
        executing block: @escaping (Error?) -> Void
    ) {
        databaseService.performAsync { [weak self] optionalContext, optionalError in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    try strongSelf.deleteAll(in: context)

                    try context.save()

                    strongSelf.call(block: block, error: nil, queue: queue)

                } catch {
                    context.rollback()

                    strongSelf.call(block: block, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, error: optionalError, queue: queue)
            }
        }
    }
}
