import BigInt
@testable import fearless
import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest

final class CovGRuntimeConstantsTests: XCTestCase {
    func testPrimitiveAndCompoundConstantsAreDeliveredOnMainQueue() throws {
        let runtime = try StakingConstantRuntime()
        let fetcher = CovGConstantFetcher()
        let primitive: UInt32 = try collect {
            fetcher.fetchConstant(for: .existentialDeposit, runtimeCodingService: runtime, operationManager: OperationManager(), closure: $0)
        }
        XCTAssertEqual(primitive, 5)
        let compound: fearless.StringScaleMapper<UInt32> = try collect {
            fetcher.fetchCompoundConstant(for: .existentialDeposit, runtimeCodingService: runtime, operationManager: OperationManager(), closure: $0)
        }
        XCTAssertEqual(compound.value, 5)
    }

    func testMissingMetadataRuntimeErrorsAndCancelledOperationsAreReported() throws {
        let runtime = try StakingConstantRuntime(values: [:])
        let fetcher = CovGConstantFetcher()
        XCTAssertThrowsError(try collect { (callback: @escaping (Result<UInt32, Error>) -> Void) in
            fetcher.fetchConstant(for: .existentialDeposit, runtimeCodingService: runtime, operationManager: OperationManager(), closure: callback)
        })
        runtime.failure = NSError(domain: "CovG.runtime", code: 89)
        XCTAssertThrowsError(try collect { (callback: @escaping (Result<UInt32, Error>) -> Void) in
            fetcher.fetchConstant(for: .existentialDeposit, runtimeCodingService: runtime, operationManager: OperationManager(), closure: callback)
        }) { XCTAssertEqual(($0 as NSError).code, 89) }
        XCTAssertThrowsError(try collect { (callback: @escaping (Result<String, Error>) -> Void) in
            fetcher.fetchCompoundConstant(for: .existentialDeposit, runtimeCodingService: runtime, operationManager: OperationManager(), closure: callback)
        }) { XCTAssertEqual(($0 as NSError).code, 89) }
        XCTAssertThrowsError(try collect { (callback: @escaping (Result<UInt32, Error>) -> Void) in
            fetcher.fetchConstant(for: .existentialDeposit, runtimeCodingService: runtime, operationManager: CovGCancellingManager(), closure: callback)
        }) { XCTAssertTrue($0 is BaseOperationError) }
        XCTAssertThrowsError(try collect { (callback: @escaping (Result<String, Error>) -> Void) in
            fetcher.fetchCompoundConstant(for: .existentialDeposit, runtimeCodingService: runtime, operationManager: CovGCancellingManager(), closure: callback)
        }) { XCTAssertTrue($0 is BaseOperationError) }
    }

    func testExistentialDepositSelectsNormalOrEquilibriumConstantAndReportsMissingRuntime() throws {
        let runtime = try StakingConstantRuntime(values: [.existentialDeposit: 5, .equilibriumExistentialDeposit: 7])
        let registry = CovGHistoryRegistry()
        registry.provider = CovGConstantRuntimeProvider(base: runtime)
        let service = ExistentialDepositService(operationManager: OperationManager(), chainRegistry: registry, chainId: "1")
        for (type, expected) in [(SubstrateAssetType.normal, BigUInt(5)), (.equilibrium, BigUInt(7))] {
            let asset = AssetModel(id: "7", name: "Asset", symbol: "UNIT", precision: 12, isUtility: false, isNative: false, type: type)
            let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: asset)
            let result: BigUInt = try collect { service.fetchExistentialDeposit(chainAsset: chainAsset, completion: $0) }
            XCTAssertEqual(result, expected)
        }
        registry.provider = nil
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        var result: Result<BigUInt, Error>?
        service.fetchExistentialDeposit(chainAsset: chainAsset) { result = $0 }
        XCTAssertThrowsError(try XCTUnwrap(result).get()) { XCTAssertTrue($0 is ChainRegistryError) }
    }

    private func collect<T>(_ action: (@escaping (Result<T, Error>) -> Void) -> Void) throws -> T {
        let done = expectation(description: "constant callback")
        var received: Result<T, Error>?
        action { XCTAssertTrue(Thread.isMainThread); received = $0; done.fulfill() }
        wait(for: [done], timeout: 10)
        return try XCTUnwrap(received).get()
    }
}

private struct CovGConstantFetcher: RuntimeConstantFetching {}

private final class CovGCancellingManager: OperationManagerProtocol {
    func enqueue(operations: [Operation], in _: OperationMode) {
        operations.forEach { $0.cancel() }
        OperationQueue().addOperations(operations, waitUntilFinished: false)
    }
}

final class CovGConstantRuntimeProvider: RuntimeProviderProtocol {
    let base: RuntimeCodingServiceProtocol
    var snapshot: RuntimeSnapshot? {
        base.snapshot
    }

    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    init(base: RuntimeCodingServiceProtocol) {
        self.base = base
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot {
        guard let snapshot else { throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable }
        return snapshot
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        base.fetchCoderFactoryOperation()
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try await base.fetchCoderFactory()
    }
}
