import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class CovBEvFixture {
    typealias Fx = CovBSkFixtures

    let facade: SubstrateStorageTestFacade
    let manager = OperationManager()
    let source: AssetHubStorageFixture
    let engine: CovBSkEngine
    let registry = CovBSkRegistry()
    let chain = Fx.chain()
    let service: EraValidatorService

    init(
        facade: SubstrateStorageTestFacade = SubstrateStorageTestFacade(),
        source: AssetHubStorageFixture? = nil,
        requestTimeout: TimeInterval = 30
    ) throws {
        self.facade = facade
        let source = try source ?? AssetHubStorageFixture()
        self.source = source
        engine = CovBSkEngine(source: source)
        registry.register(chain.chainId, connection: engine, runtime: source.runtime)
        service = EraValidatorService(
            chain: chain,
            storageFacade: facade,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            operationManager: manager,
            eventCenter: EventCenterProtocolStub(),
            chainRegistry: registry,
            requestTimeout: requestTimeout
        )
    }

    static func eraItem(_ era: UInt32) -> ChainStorageItem {
        var data = withUnsafeBytes(of: era.littleEndian) { Data($0) }
        data.append(0)
        return ChainStorageItem(identifier: "covb-active-era", data: data)
    }

    func deliver(_ item: ChainStorageItem?) {
        service.syncQueue.async { self.service.didUpdateActiveEraItem(item) }
    }

    func putValidator(_ id: Data, era: UInt32, prefs: Bool = true, total: Int = 300, own: Int = 100, pages: [[(Data, Int)]]) throws {
        if prefs {
            _ = try source.put(.validatorPrefs, json: "{\"commission\":\"200000000\",\"blocked\":false}", account: id)
        }
        let count = pages.reduce(0) { $0 + $1.count }
        let overview = "{\"total\":\"\(total)\",\"own\":\"\(own)\",\"nominator_count\":\"\(count)\",\"page_count\":\"\(pages.count)\"}"
        _ = try source.put(.erasStakersOverview, json: overview, era: era, account: id)
        for (index, page) in pages.enumerated() {
            let others = page.map { "{\"who\":\"\($0.0.toHex(includePrefix: true))\",\"value\":\"\($0.1)\"}" }.joined(separator: ",")
            let pageTotal = page.reduce(0) { $0 + $1.1 }
            let json = "{\"page_total\":\"\(pageTotal)\",\"others\":[\(others)]}"
            _ = try source.put(.erasStakersPaged, json: json, era: era, account: id, page: UInt32(index))
        }
    }

    func removeStored(_ path: fearless.StorageCodingPath) throws {
        let prefix = try StorageKeyFactory().createStorageKey(moduleName: path.moduleName, storageName: path.itemName)
            .toHex(includePrefix: true)
        source.values = source.values.filter { !$0.key.hasPrefix(prefix) }
    }

    func fetch(timeout: TimeInterval = 30) throws -> EraStakersInfo {
        let operation = service.fetchInfoOperation()
        let done = XCTestExpectation(description: "era info")
        operation.completionBlock = { done.fulfill() }
        manager.enqueue(operations: [operation], in: .transient)
        guard XCTWaiter.wait(for: [done], timeout: timeout) == .completed else { throw CovBSkError(code: 404) }
        return try XCTUnwrap(operation.result).get()
    }
}

final class CovBEvPagedStakersTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testRemoteReadJoinsOverviewPagesAndPrefs() throws {
        let fx = try CovBEvFixture()
        try fx.putValidator(Fx.validatorA, era: 10, pages: [[(Fx.nominator, 150)], [(Fx.other, 50)]])
        try fx.putValidator(Fx.validatorB, era: 10, prefs: false, pages: [[(Fx.nominator, 20)]])
        try fx.putValidator(Fx.validatorC, era: 10, total: 70, own: 70, pages: [])
        try fx.putValidator(Fx.validatorD, era: 9, pages: [[(Fx.nominator, 1)]])

        fx.deliver(CovBEvFixture.eraItem(10))
        let info = try fx.fetch()

        XCTAssertEqual(info.activeEra, 10)
        XCTAssertEqual(fx.service.syncQueue.sync { fx.service.activeEra }, 10)
        let validators = Dictionary(uniqueKeysWithValues: info.validators.map { ($0.accountId, $0) })
        XCTAssertEqual(Set(validators.keys), [Fx.validatorA, Fx.validatorC], "B has no prefs and D belongs to another era")
        let validatorA = try XCTUnwrap(validators[Fx.validatorA])
        XCTAssertEqual(validatorA.exposure.total, 300)
        XCTAssertEqual(validatorA.exposure.own, 100)
        XCTAssertEqual(Set(validatorA.exposure.others.map(\.who)), [Fx.nominator, Fx.other])
        XCTAssertEqual(validatorA.exposure.others.map(\.value).reduce(0, +), 200)
        XCTAssertEqual(validatorA.prefs.commission, 200_000_000)
        XCTAssertEqual(validators[Fx.validatorC]?.exposure.others.count, 0)
        XCTAssertEqual(validators[Fx.validatorC]?.exposure.total, 70)
    }

    func testSecondServiceReadsExposuresFromTheLocalCache() throws {
        let first = try CovBEvFixture()
        try first.putValidator(Fx.validatorA, era: 10, pages: [[(Fx.nominator, 150)]])
        first.deliver(CovBEvFixture.eraItem(10))
        XCTAssertEqual(try first.fetch().validators.map(\.accountId), [Fx.validatorA])

        try first.removeStored(.erasStakersOverview)
        let second = try CovBEvFixture(facade: first.facade, source: first.source)
        second.deliver(CovBEvFixture.eraItem(10))
        let info = try second.fetch()

        XCTAssertEqual(info.validators.map(\.accountId), [Fx.validatorA], "The overview comes from the cached exposures")
        XCTAssertEqual(info.validators.first?.exposure.total, 300)
        XCTAssertEqual(info.validators.first?.exposure.others.map(\.who), [Fx.nominator])
    }

    func testCachedExposuresOfAnotherEraAreNotReused() throws {
        let first = try CovBEvFixture()
        try first.putValidator(Fx.validatorA, era: 10, pages: [])
        first.deliver(CovBEvFixture.eraItem(10))
        XCTAssertEqual(try first.fetch().validators.count, 1)

        let second = try CovBEvFixture(facade: first.facade, source: first.source)
        try second.putValidator(Fx.validatorB, era: 11, pages: [])
        second.deliver(CovBEvFixture.eraItem(11))
        let info = try second.fetch()

        XCTAssertEqual(info.activeEra, 11)
        XCTAssertEqual(info.validators.map(\.accountId), [Fx.validatorB])
    }

    func testNodeFailureIsDeliveredToWaitingRequests() throws {
        let fx = try CovBEvFixture()
        try fx.putValidator(Fx.validatorA, era: 10, pages: [])
        fx.engine.failure = CovBSkError(code: 61)
        fx.deliver(CovBEvFixture.eraItem(10))
        XCTAssertThrowsError(try fx.fetch()) { error in
            XCTAssertNotEqual(error as? CovBSkError, CovBSkError(code: 404), "The failure arrives before the wait ends")
            if case EraValidatorServiceError.requestTimedOut = error { XCTFail("The failure is reported, not a timeout") }
        }
    }

    func testUndecodableActiveEraIsReported() throws {
        let fx = try CovBEvFixture()
        fx.deliver(ChainStorageItem(identifier: "covb-active-era", data: Data([1])))
        XCTAssertThrowsError(try fx.fetch()) { error in
            XCTAssertNotEqual(error as? CovBSkError, CovBSkError(code: 404))
            if case EraValidatorServiceError.requestTimedOut = error { XCTFail("The decoding failure is reported") }
        }
    }

    func testMissingRuntimeIsReported() throws {
        let fx = try CovBEvFixture()
        fx.registry.register(fx.chain.chainId, connection: fx.engine, runtime: nil)
        fx.deliver(CovBEvFixture.eraItem(10))
        XCTAssertThrowsError(try fx.fetch()) { error in
            guard case ChainRegistryError.runtimeMetadaUnavailable = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testMissingEraItemKeepsRequestsWaitingUntilTheyTimeOut() throws {
        let fx = try CovBEvFixture(requestTimeout: 0.2)
        fx.deliver(nil)
        XCTAssertThrowsError(try fx.fetch()) { error in
            guard case EraValidatorServiceError.requestTimedOut = error else { return XCTFail("unexpected \(error)") }
        }
        XCTAssertNil(fx.service.syncQueue.sync { fx.service.lastActiveEraItem })
    }

    func testMissingConnectionFailsTheRemoteRead() throws {
        let fx = try CovBEvFixture()
        fx.registry.register(fx.chain.chainId, connection: nil, runtime: fx.source.runtime)
        fx.deliver(CovBEvFixture.eraItem(10))
        XCTAssertThrowsError(try fx.fetch()) { error in
            guard case ChainRegistryError.connectionUnavailable = error else { return XCTFail("unexpected \(error)") }
        }
    }
}

final class CovBEvLifecycleTests: XCTestCase {
    private final class CovBEvProviderFactory: SubstrateDataProviderFactoryProtocol {
        let underlying: SubstrateDataProviderFactory
        private(set) var storageKeys: [String] = []

        init(facade: fearless.StorageFacadeProtocol, manager: OperationManagerProtocol) {
            underlying = SubstrateDataProviderFactory(facade: facade, operationManager: manager)
        }

        func createStashItemProvider(for address: String) -> StreamableProvider<StashItem> {
            underlying.createStashItemProvider(for: address)
        }

        func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem> {
            storageKeys.append(key)
            return underlying.createStorageProvider(for: key)
        }
    }

    func testThrottleBeforeSetupLeavesTheServiceReadyToSubscribe() throws {
        let facade = SubstrateStorageTestFacade()
        let manager = OperationManager()
        let provider = CovBEvProviderFactory(facade: facade, manager: manager)
        let chain = CovBSkFixtures.chain()
        let service = EraValidatorService(
            chain: chain,
            storageFacade: facade,
            providerFactory: provider,
            operationManager: manager,
            eventCenter: EventCenterProtocolStub(),
            chainRegistry: CovBSkRegistry()
        )

        service.throttle()
        service.setup()
        service.syncQueue.sync {}

        XCTAssertEqual(provider.storageKeys, [try LocalStorageKeyFactory().createFromStoragePath(.activeEra, chainId: chain.chainId)])
    }
}
