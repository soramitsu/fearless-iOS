/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreData
import Foundation

/**
 *  Protocol is designed to provide an interface for mapping swift identifiable model
 *  to Core Data NSManageObjectContext and back. It is expected that NSManagedObject
 *  contains a field to store identifier.
 */

public protocol CoreDataMapperProtocol: AnyObject {
    associatedtype DataProviderModel: Identifiable
    associatedtype CoreDataEntity: NSManagedObject

    /**
     *  Transforms Core Data entity to swift model.
     *
     *  - parameters:
     *    - entity: Subclass of NSManagedObject to convert to swift model.
     *  - returns: Identifiable swift model.
     */

    func transform(entity: CoreDataEntity) throws -> DataProviderModel

    /**
     *  Converts swift model to NSManagedObject.
     *
     *  - note: Because NSManagedObject can be created manually the method expects to
     *  receive a reference to it as a parameter.
     *
     *  - parameters:
     *    - entity: Subclass of NSManagedObject to populate from swift model.
     *    - model: Swift model to populate NSManagedObject from.
     *    - context: Core Data context to created nested object if needed.
     */

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws

    /// Create dict value for batch saves (Optional for mappers)
    /// - Parameter model: Swift model to populate NSManagedObject from.
    /// - Returns: [String: Any]
    func dict(for model: DataProviderModel) throws -> [String: Any]

    /// Name of idetifier field to access NSManagedObject by.
    var entityIdentifierFieldName: String { get }
}

public extension CoreDataMapperProtocol {
    func dict(for _: DataProviderModel) throws -> [String: Any] { [:] }
}

/**
 *  Class is designed to apply type erasure technique to ```CoreDataMapperProtocol```.
 */

public final class AnyCoreDataMapper<T: Identifiable, U: NSManagedObject>: CoreDataMapperProtocol {
    public typealias DataProviderModel = T
    public typealias CoreDataEntity = U

    private let _transform: (CoreDataEntity) throws -> DataProviderModel
    private let _populate: (CoreDataEntity, DataProviderModel, NSManagedObjectContext) throws
        -> Void
    private let _dict: (DataProviderModel) throws -> [String: Any]
    private let _entityIdentifierFieldName: String

    /**
     *  Initializes type erasure wrapper for mapper implementation.
     *
     *  - parameters:
     *    - mapper: Core Data mapper implementation to erase type of.
     */

    public init<M: CoreDataMapperProtocol>(_ mapper: M) where M.DataProviderModel == T,
        M.CoreDataEntity == U
    {
        _transform = mapper.transform
        _populate = mapper.populate
        _entityIdentifierFieldName = mapper.entityIdentifierFieldName
        _dict = mapper.dict
    }

    public func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        try _transform(entity)
    }

    public func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        try _populate(entity, model, context)
    }

    public var entityIdentifierFieldName: String {
        _entityIdentifierFieldName
    }
    
    public func dict(for model: DataProviderModel) throws -> [String: Any] {
        try _dict(model)
    }
}

/**
 *  Protocol is designed to serialize/deserialize subclass of NSManagedObject.
 */

public protocol CoreDataCodable: Encodable {
    /**
     *  Populates subclass of NSManagedObject from decoder.
     *
     *  Due to the fact that NSManagedObject can't be created manually from
     *  raw data it is assumed that the object is already allocated and only
     *  needs to be populated with field values.
     *
     *  - parameters:
     *    - decoder: Object to extract decoded data from.
     *    - context: Core Data context to fetch/create nested objects.
     */

    func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws
}

private class CoreDataDecodingContainer: Decodable {
    var decoder: Decoder

    required init(from decoder: Decoder) throws {
        self.decoder = decoder
    }

    func populate(entity: CoreDataCodable, using context: NSManagedObjectContext) throws {
        try entity.populate(from: decoder, using: context)
    }
}

/**
 *  Class is designed to provide implementation of ```CoreDataMapperProtocol```.
 *  Implementation assumes that swift model conforms to ```Codable``` protocol.
 */

public final class CodableCoreDataMapper<
    T: Identifiable & Codable,
    U: NSManagedObject & CoreDataCodable
>: CoreDataMapperProtocol {
    public typealias DataProviderModel = T
    public typealias CoreDataEntity = U

    public var entityIdentifierFieldName: String

    /**
     *  Creates Core Data mapper object.
     *
     *  - parameters:
     *    - entityIdentifierFieldName: Field name to extract identifier by. By default ```identifier```.
     */

    public init(entityIdentifierFieldName: String = "identifier") {
        self.entityIdentifierFieldName = entityIdentifierFieldName
    }

    public func transform(entity: U) throws -> T {
        let data = try JSONEncoder().encode(entity)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func populate(entity: U, from model: T, using context: NSManagedObjectContext) throws {
        let data = try JSONEncoder().encode(model)
        let container = try JSONDecoder().decode(
            CoreDataDecodingContainer.self,
            from: data
        )
        try container.populate(entity: entity, using: context)
    }

    public func dict(for model: T) throws -> [String : Any] {
        let data = try JSONEncoder().encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json = json else {
            throw CoreDataRepositoryError.creationFailed
        }
        return json
    }
}
