import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovFRepository<T: RobinHood.Identifiable>: DataProviderRepositoryProtocol {
    var items: [T]
    var failure: Error?
    var requestedIds: [String] = []

    init(_ items: [T] = []) { self.items = items }

    func fetchOperation(by ids: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation {
            self.requestedIds = try ids()
            if let failure = self.failure { throw failure }
            return self.items.filter { self.requestedIds.contains($0.identifier) }
        }
    }

    func fetchOperation(by id: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<T?> {
        ClosureOperation {
            self.requestedIds = [try id()]
            if let failure = self.failure { throw failure }
            return self.items.first { self.requestedIds.contains($0.identifier) }
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        ClosureOperation {
            if let failure = self.failure { throw failure }
            return self.items
        }
    }

    func fetchOperation(by _: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        fetchAllOperation(with: options)
    }

    func saveOperation(_ updates: @escaping () throws -> [T], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {
            let removed = try deletes()
            let updated = try updates()
            let replaced = Set(updated.map(\.identifier))
            self.items.removeAll { removed.contains($0.identifier) || replaced.contains($0.identifier) }
            self.items.append(contentsOf: updated)
        }
    }

    func saveBatchOperation(_ updates: @escaping () throws -> [T], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> {
        saveOperation(updates, deletes)
    }

    func replaceOperation(_ items: @escaping () throws -> [T]) -> BaseOperation<Void> {
        ClosureOperation { self.items = try items() }
    }

    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.items.count } }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation { self.items.removeAll() } }
}

final class CovFRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    var runtime: RuntimeProviderProtocol?
    var connection: ChainConnection?
    override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { runtime }
    override func getConnection(for _: ChainModel.Id) -> ChainConnection? { connection }
}

final class CovFRuntime: RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    let snapshot: RuntimeSnapshot? = nil
    let factory: RuntimeCoderFactoryProtocol
    var failure: Error?

    init(factory: RuntimeCoderFactoryProtocol) { self.factory = factory }
    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        if let failure { throw failure }
        return factory
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation {
            if let failure = self.failure { throw failure }
            return self.factory
        }
    }
}

enum CovFFixtures {
    static let account = Data(repeating: 1, count: 32)

    static func asset(type: SubstrateAssetType? = .normal, utility: Bool = true, ethereum: Bool = false) -> ChainAsset {
        let asset = AssetModel(
            id: "0", name: "Test", symbol: "TEST", precision: 2, currencyId: "1",
            isUtility: utility, isNative: utility, staking: .relayChain, type: type,
            ethereumType: ethereum ? .normal : nil
        )
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: String(repeating: "ab", count: 32), parentId: nil,
            paraId: nil, name: "Coverage", assets: [asset], xcm: nil, nodes: [], addressPrefix: 42,
            icon: nil, options: ethereum ? [.ethereum] : nil, iosMinAppVersion: nil, identityChain: nil
        )
        return ChainAsset(chain: chain, asset: asset)
    }

    static func execute<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }

    static func result<T>(_ value: T) -> BaseOperation<T> {
        let operation = BaseOperation<T>()
        operation.result = .success(value)
        return operation
    }

    static func json(_ value: Any) throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed))
    }

    static func runtime(path: fearless.StorageCodingPath, type: String, definitions: String) throws -> CovFRuntime {
        let entry = RuntimeMetadataV1.StorageEntryMetadata(
            name: path.itemName, modifier: .optional, type: .plain(PlainEntry(stringValue: type)), defaultValue: Data(), documentation: []
        )
        let module = RuntimeMetadataV1.ModuleMetadata(
            name: path.moduleName, storage: .init(prefix: path.moduleName, entries: [entry]), calls: nil,
            events: nil, constants: [], errors: [], index: 0
        )
        let metadata = try RuntimeMetadata.v1(modules: [module], extrinsic: .init(version: 4, signedExtensions: []))
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(definitions.utf8)) as? [String: [String: Any]])
        let types = (raw["types"] ?? [:]).mapValues { value -> Any in
            guard let fields = value as? [String: Any] else { return value }
            let members = (fields["_enum"] as? [String: Any]) ?? fields
            return ["type": fields["_enum"] == nil ? "struct" : "enum",
                    "type_mapping": members.keys.sorted().map { [$0, members[$0] ?? ""] }]
        }
        let data = try JSONSerialization.data(withJSONObject: ["types": types])
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(data, runtimeMetadata: metadata, usedRuntimePaths: [:])
        return CovFRuntime(factory: TestRuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata))
    }
}
