import Foundation
import SSFUtils
import SSFRuntimeCodingService

/// All pages and values belong to one finalized block. Exhaustion never returns partial success.
struct AssetHubPagedStorage {
    struct PageRequest: Codable {
        let prefix: String
        let count: Int
        let start: String?
        let block: String

        func encode(to encoder: Encoder) throws {
            var values = encoder.unkeyedContainer()
            try values.encode(prefix)
            try values.encode(count)
            try values.encode(start)
            try values.encode(block)
        }
    }

    enum Failure: Error {
        case invalidPage
        case limitExceeded
        case incompatibleMetadata
    }

    let engine: JSONRPCEngine
    let runtime: RuntimeCoderFactoryProtocol
    let block: Data
    let storage: AsyncStorageRequestFactory
    var maximumKeys = 200_000
    var maximumDuration: TimeInterval = 180
    static let pageSize = 128

    static func validatePage(_ keys: [Data], prefix: Data, after previous: Data?, remaining: Int) throws {
        guard keys.count <= pageSize, keys.count <= remaining else { throw Failure.limitExceeded }
        var last = previous
        for key in keys {
            guard key.starts(with: prefix), key.count > prefix.count,
                  last.map({ $0.lexicographicallyPrecedes(key) }) ?? true else { throw Failure.invalidPage }
            last = key
        }
    }

    func forEachPage<Value: Decodable>(
        path: StorageCodingPath,
        consume: ([StorageResponse<Value>]) async throws -> Void
    ) async throws {
        let prefix = try StorageKeyFactory().key(from: path)
        let started = Date()
        var previous: Data?
        var remaining = maximumKeys
        while true {
            try Task.checkCancellation()
            guard Date().timeIntervalSince(started) < maximumDuration else { throw Failure.limitExceeded }
            let request = PageRequest(
                prefix: prefix.toHex(includePrefix: true),
                count: Self.pageSize,
                start: previous?.toHex(includePrefix: true),
                block: block.toHex(includePrefix: true)
            )
            let encoded: [String] = try await JSONRPCWorker<PageRequest, [String]>(
                engine: engine, method: "state_getKeysPaged", parameters: request
            ).performCall()
            let keys = try encoded.map { try Data(hexStringSSF: $0) }
            try Self.validatePage(keys, prefix: prefix, after: previous, remaining: remaining)
            if keys.isEmpty { return }
            let values: [StorageResponse<Value>] = try await storage.queryItems(
                engine: engine, keys: keys, factory: runtime, storagePath: path, at: block
            )
            guard values.count == keys.count, values.map(\.key) == keys else { throw Failure.invalidPage }
            try await consume(values)
            remaining -= keys.count
            previous = keys.last
        }
    }

    func decodeKey<Value: Decodable>(_ key: Data, path: StorageCodingPath, type: MapKeyType) throws -> Value {
        guard let entry = runtime.metadata.getStorageMetadata(for: path),
              case let .nMap(map) = entry.type else { throw Failure.incompatibleMetadata }
        let components = try map.keys(using: runtime.metadata.schemaResolver)
        let expectedCount = type == .erasStakersPagedKey ? 3 : 2
        let expectedBytes = type == .erasStakersPagedKey ? 96 : 84
        guard components.count == expectedCount, map.hashers.count == expectedCount,
              map.hashers.allSatisfy({ $0 == .twox64Concat }), key.count == expectedBytes,
              key.starts(with: try StorageKeyFactory().key(from: path)),
              let keyType = try entry.type.keyName(schemaResolver: runtime.metadata.schemaResolver) else {
            throw Failure.incompatibleMetadata
        }
        let bytes = try Data(hexStringSSF: type.extractKeys(from: key.toHex()))
        return try runtime.createDecoder(from: bytes).read(of: keyType)
    }
}
