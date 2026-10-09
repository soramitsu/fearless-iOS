import CoreData
import Foundation
import RobinHood
import SSFUtils
import SSFModels

struct RuntimeMetadataItem: Codable & Equatable {
    let chain: String
    let version: UInt32
    let txVersion: UInt32
    let metadata: Data

    enum CodingKeys: String, CodingKey {
        case chain
        case version
        case txVersion
        case metadata
    }

    init(
        chain: String,
        version: UInt32,
        txVersion: UInt32,
        metadata: Data
    ) {
        self.chain = chain
        self.version = version
        self.txVersion = txVersion
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        chain = try container.decode(String.self, forKey: .chain)
        version = try container.decode(UInt32.self, forKey: .version)
        txVersion = try container.decode(UInt32.self, forKey: .txVersion)
        metadata = try container.decode(Data.self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(chain, forKey: .chain)
        try container.encode(version, forKey: .version)
        try container.encode(txVersion, forKey: .txVersion)
        try container.encode(metadata, forKey: .metadata)
    }
}

extension RuntimeMetadataItem: Identifiable {
    var identifier: String { chain }
}

extension RuntimeMetadataItem: RuntimeMetadataItemProtocol {}

/// Keeps the generic Codable mapper's valid serialization behavior while
/// converting damaged Core Data getter exceptions into a catchable,
/// payload-free Swift error during runtime hot boot.
final class RuntimeMetadataMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = RuntimeMetadataItem
    typealias CoreDataEntity = CDRuntimeMetadataItem

    private let mapper =
        CodableCoreDataMapper<
            RuntimeMetadataItem,
            CDRuntimeMetadataItem
        >()

    var entityIdentifierFieldName: String {
        mapper.entityIdentifierFieldName
    }

    func transform(
        entity: CDRuntimeMetadataItem
    ) throws -> RuntimeMetadataItem {
        var item: RuntimeMetadataItem?

        try SafeObjectiveCExceptionBoundary.perform {
            item = try self.mapper.transform(entity: entity)
        }

        guard let item else {
            throw SafeTransformableValueReaderError
                .objectiveCException
        }

        return item
    }

    func populate(
        entity: CDRuntimeMetadataItem,
        from model: RuntimeMetadataItem,
        using context: NSManagedObjectContext
    ) throws {
        try SafeObjectiveCExceptionBoundary.perform {
            try self.mapper.populate(
                entity: entity,
                from: model,
                using: context
            )
        }
    }

    func dict(
        for model: RuntimeMetadataItem
    ) throws -> [String: Any] {
        try mapper.dict(for: model)
    }
}
