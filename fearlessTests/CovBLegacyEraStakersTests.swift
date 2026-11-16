import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

/// A relay chain runtime before paged exposures: the Polkadot 9370 metadata the app bundles (Staking.ErasStakers, no
/// ErasStakersOverview), with its V14 type schema, served without a snapshot.
enum CovBLgRuntime {
    static func factory() throws -> RuntimeCoderFactoryProtocol {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "polkadot-9370metadata", withExtension: nil))
        let hex = try String(contentsOf: url).components(separatedBy: .whitespacesAndNewlines).joined()
        let metadata = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: Data(hexStringSSF: hex)))
        let definition = Data("{\"types\":{\"Index\":\"u32\",\"Balance\":\"u128\"}}".utf8)
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(definition, runtimeMetadata: metadata, usedRuntimePaths: [:])
        return TestRuntimeCoderFactory(catalog: catalog, specVersion: 9370, txVersion: 20, metadata: metadata)
    }
}

final class CovBLgFixture {
    typealias Fx = CovBSkFixtures

    let facade: SubstrateStorageTestFacade
    let manager = OperationManager()
    let source: AssetHubStorageFixture
    let engine: CovBSkEngine
    let registry = CovBSkRegistry()
    let chain = Fx.chain(id: "covb-legacy")
    let service: EraValidatorService

    init(facade: SubstrateStorageTestFacade = SubstrateStorageTestFacade(), source: AssetHubStorageFixture? = nil) throws {
        self.facade = facade
        let store: AssetHubStorageFixture
        if let source = source {
            store = source
        } else {
            store = try AssetHubStorageFixture()
            store.values = [:]
        }
        self.source = store
        engine = CovBSkEngine(source: store)
        let factory = try CovBLgRuntime.factory()
        XCTAssertNotNil(factory.metadata.getStorageMetadata(for: fearless.StorageCodingPath.erasStakers))
        XCTAssertNil(factory.metadata.getStorageMetadata(for: fearless.StorageCodingPath.erasStakersOverview), "The legacy runtime has no paged exposures")
        registry.register(chain.chainId, connection: engine, runtime: CovBSkRuntimeProvider(RuntimeCodingServiceStub(factory: factory)))
        service = EraValidatorService(
            chain: chain,
            storageFacade: facade,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            operationManager: manager,
            eventCenter: EventCenterProtocolStub(),
            chainRegistry: registry,
            requestTimeout: 30
        )
    }

    static func compact(_ value: UInt64) -> Data {
        switch value {
        case 0 ..< 64:
            return Data([UInt8(value << 2)])
        case 64 ..< 16384:
            return withUnsafeBytes(of: (UInt16(value) << 2 | 1).littleEndian) { Data($0) }
        default:
            return withUnsafeBytes(of: (UInt32(value) << 2 | 2).littleEndian) { Data($0) }
        }
    }

    static func eraBytes(_ era: UInt32) -> Data {
        withUnsafeBytes(of: era.littleEndian) { Data($0) }
    }

    func exposureKey(era: UInt32, account: Data) throws -> Data {
        try StorageKeyFactory().createStorageKey(
            moduleName: "Staking", storageName: "ErasStakers",
            key1: Self.eraBytes(era), hasher1: .twox64Concat, key2: account, hasher2: .twox64Concat
        )
    }

    func putExposure(era: UInt32, account: Data, total: UInt64, own: UInt64, others: [(Data, UInt64)]) throws {
        var value = Self.compact(total) + Self.compact(own) + Self.compact(UInt64(others.count))
        for (who, stake) in others {
            value += who + Self.compact(stake)
        }
        source.values[try exposureKey(era: era, account: account).toHex(includePrefix: true)] = value.toHex(includePrefix: true)
    }

    func putPrefs(account: Data, commission: UInt64, blocked: Bool) throws {
        let key = try StorageKeyFactory().createStorageKey(
            moduleName: "Staking", storageName: "Validators", key: account, hasher: .twox64Concat
        )
        let value = Self.compact(commission) + Data([blocked ? 1 : 0])
        source.values[key.toHex(includePrefix: true)] = value.toHex(includePrefix: true)
    }

    func deliver(era: UInt32) {
        let item = ChainStorageItem(identifier: "covb-legacy-era", data: Self.eraBytes(era) + Data([0]))
        service.syncQueue.async { self.service.didUpdateActiveEraItem(item) }
    }

    func fetch(timeout: TimeInterval = 30) throws -> EraStakersInfo {
        let operation = service.fetchInfoOperation()
        let done = XCTestExpectation(description: "legacy era info")
        operation.completionBlock = { done.fulfill() }
        manager.enqueue(operations: [operation], in: .transient)
        guard XCTWaiter.wait(for: [done], timeout: timeout) == .completed else { throw CovBSkError(code: 404) }
        return try XCTUnwrap(operation.result).get()
    }
}

final class CovBLgEraStakersTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testRemoteReadPairsExposuresWithPrefsAndSortsNominatorsByStake() throws {
        let fx = try CovBLgFixture()
        try fx.putExposure(era: 10, account: Fx.validatorA, total: 500, own: 250, others: [(Fx.other, 50), (Fx.nominator, 200)])
        try fx.putExposure(era: 10, account: Fx.validatorB, total: 90, own: 90, others: [])
        try fx.putExposure(era: 9, account: Fx.validatorC, total: 70, own: 70, others: [])
        try fx.putPrefs(account: Fx.validatorA, commission: 100_000_000, blocked: true)
        try fx.putPrefs(account: Fx.validatorC, commission: 0, blocked: false)

        fx.deliver(era: 10)
        let info = try fx.fetch()

        XCTAssertEqual(info.activeEra, 10)
        let byId = Dictionary(uniqueKeysWithValues: info.validators.map { ($0.accountId, $0) })
        XCTAssertNil(byId[Fx.validatorC], "C's exposure belongs to another era")
        let validator = try XCTUnwrap(byId[Fx.validatorA])
        XCTAssertEqual(validator.exposure.total, 500)
        XCTAssertEqual(validator.exposure.own, 250)
        XCTAssertEqual(validator.exposure.others.map(\.who), [Fx.nominator, Fx.other])
        XCTAssertEqual(validator.exposure.others.map(\.value), [200, 50])
        XCTAssertEqual(validator.prefs.commission, 100_000_000)
        XCTAssertTrue(validator.prefs.blocked)
        // Current behaviour (reported): the legacy path reads prefs per exposure key, and an absent Staking.Validators
        // entry decodes to the storage default, so B is kept with no commission. The paged path skips such validators.
        XCTAssertEqual(Set(byId.keys), [Fx.validatorA, Fx.validatorB])
        let unlisted = try XCTUnwrap(byId[Fx.validatorB])
        XCTAssertEqual(unlisted.prefs.commission, 0)
        XCTAssertFalse(unlisted.prefs.blocked)
        XCTAssertEqual(unlisted.exposure.total, 90)
        XCTAssertTrue(fx.engine.methods.contains("state_getKeysPaged"))
    }

    func testCachedExposuresAreReadLocallyByTheNextService() throws {
        let first = try CovBLgFixture()
        try first.putExposure(era: 10, account: Fx.validatorA, total: 500, own: 250, others: [(Fx.nominator, 250)])
        try first.putPrefs(account: Fx.validatorA, commission: 0, blocked: false)
        first.deliver(era: 10)
        XCTAssertEqual(try first.fetch().validators.count, 1)

        let exposureKey = try first.exposureKey(era: 10, account: Fx.validatorA).toHex(includePrefix: true)
        first.source.values.removeValue(forKey: exposureKey)
        let second = try CovBLgFixture(facade: first.facade, source: first.source)
        second.deliver(era: 10)
        let info = try second.fetch()

        XCTAssertEqual(info.validators.map(\.accountId), [Fx.validatorA], "The exposure comes from the local cache")
        XCTAssertEqual(info.validators.first?.exposure.others.map(\.who), [Fx.nominator])
        XCTAssertFalse(second.engine.methods.contains("state_getKeysPaged"), "Cached eras do not list keys again")
    }
}
