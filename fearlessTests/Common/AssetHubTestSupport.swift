import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// Shared values and helpers for the Asset Hub staking tests.
enum AssetHubTestSupport {
    static let first = Data(repeating: 1, count: 32)
    static let second = Data(repeating: 2, count: 32)
    static let nominator = Data(repeating: 3, count: 32)

    /// A validator whose only nominator is `nominator`, with 200 of its stake.
    static func validator(
        _ id: Data,
        stake: BigUInt = 300,
        own: BigUInt = 100,
        commission: BigUInt = 200_000_000
    ) throws -> EraValidatorInfo {
        let data = try JSONSerialization.data(withJSONObject: ["who": nominator.base64EncodedString(), "value": "200"])
        let others = try [JSONDecoder().decode(IndividualExposure.self, from: data)]
        return EraValidatorInfo(
            accountId: id,
            exposure: ValidatorExposure(total: stake, own: own, others: others),
            prefs: ValidatorPrefs(commission: commission, blocked: false)
        )
    }

    /// A chain with one native token that stakes as a relay chain asset.
    static func makeAsset(
        chainId: ChainModel.Id,
        parentId: ChainModel.Id? = nil,
        assetId: AssetModel.Id = "0",
        staking: RawStakingType? = .relayChain,
        type: SubstrateAssetType? = nil
    ) -> ChainAsset {
        let token = AssetModel(
            id: assetId,
            name: "STAKE",
            symbol: "STAKE",
            precision: 2,
            isUtility: true,
            isNative: true,
            staking: staking,
            type: type
        )
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: parentId,
            paraId: nil,
            name: chainId,
            assets: [token],
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        return ChainAsset(chain: chain, asset: token)
    }

    static func execute<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let queue = OperationQueue()
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
}

/// A runtime whose metadata holds only the given `u32` constants.
final class StakingConstantRuntime: RuntimeCodingServiceProtocol {
    let snapshot: RuntimeSnapshot?
    let factory: RuntimeCoderFactoryProtocol
    var failure: Error?

    static let defaults: [fearless.ConstantCodingPath: UInt32] = [
        .lockUpPeriod: 28, .eraLength: 6, .sessionLength: 10, .babeBlockTime: 6000,
        .existentialDeposit: 5, .maxNominatorRewardedPerValidator: 2
    ]

    init(values: [fearless.ConstantCodingPath: UInt32] = StakingConstantRuntime.defaults) throws {
        let groups = Dictionary(grouping: values.keys, by: \.moduleName)
        let modules = try groups.keys.sorted().enumerated().map { index, module in
            let constants = try groups[module, default: []].map { path in
                RuntimeMetadataV1.ModuleConstantMetadata(
                    name: path.constantName, type: "u32",
                    value: try values[path, default: 0].scaleEncoded(), documentation: []
                )
            }
            return RuntimeMetadataV1.ModuleMetadata(
                name: module, storage: nil, calls: nil, events: nil,
                constants: constants, errors: [], index: UInt8(index)
            )
        }
        let metadata = try RuntimeMetadata.v1(
            modules: modules, extrinsic: .init(version: 4, signedExtensions: [])
        )
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data("{\"types\":{}}".utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        snapshot = RuntimeSnapshot(typeRegistryCatalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata)
        factory = TestRuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata)
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation {
            if let failure = self.failure { throw failure }
            return self.factory
        }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        if let failure { throw failure }
        return factory
    }
}

/// A runtime metadata repository that stores nothing, so a provider depends on sync events alone.
struct CrossChainRuntimeRepository: DataProviderRepositoryProtocol {
    typealias Model = fearless.RuntimeMetadataItem

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}
