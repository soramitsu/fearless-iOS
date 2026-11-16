import BigInt
@testable import fearless
import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest

final class CovGStorageDecodingTests: XCTestCase {
    func testDecodeSingleListAndFallbackValues() throws {
        let factory = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let bytes = Data([42, 0, 0, 0])
        let single = StorageDecodingOperation<fearless.StringScaleMapper<UInt32>>(path: .currentEra, data: bytes)
        single.codingFactory = factory
        XCTAssertEqual(try CovGOperationFixtures.run(single).value, 42)
        let list = StorageDecodingListOperation<fearless.StringScaleMapper<UInt32>>(path: .currentEra, dataList: [bytes, Data([43, 0, 0, 0])])
        list.codingFactory = factory
        XCTAssertEqual(try CovGOperationFixtures.run(list).map(\.value), [42, 43])
        let fallback = StorageFallbackDecodingOperation<fearless.StringScaleMapper<UInt32>>(path: .currentEra, data: bytes)
        fallback.codingFactory = factory
        XCTAssertEqual(try CovGOperationFixtures.run(fallback)?.value, 42)
        let missing = StorageFallbackDecodingOperation<fearless.StringScaleMapper<UInt32>>(path: .currentEra)
        missing.codingFactory = factory
        XCTAssertNil(try CovGOperationFixtures.run(missing))
        let fallbackList = StorageFallbackDecodingListOperation<fearless.StringScaleMapper<UInt32>>(path: .currentEra, dataList: [bytes, nil])
        fallbackList.codingFactory = factory
        XCTAssertEqual(try CovGOperationFixtures.run(fallbackList).map { $0?.value }, [42, nil])
        let defaulted = StorageFallbackDecodingOperation<fearless.StringScaleMapper<UInt32>>(path: .counterForNominators)
        defaulted.codingFactory = try AssetHubRuntimeFixture(name: "polkadot").factory
        XCTAssertEqual(try CovGOperationFixtures.run(defaulted)?.value, 0)
    }

    func testMissingConfigurationInvalidPathAndMalformedPayloadFail() throws {
        XCTAssertThrowsError(try CovGOperationFixtures.run(StorageDecodingOperation<String>(path: .currentEra)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(StorageDecodingListOperation<String>(path: .currentEra)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(StorageFallbackDecodingOperation<String>(path: .currentEra)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(StorageFallbackDecodingListOperation<String>(path: .currentEra)))
        let invalid = StorageDecodingOperation<String>(path: .tokens, data: Data())
        invalid.codingFactory = try RuntimeCodingServiceStub.createWestendCodingFactory()
        XCTAssertThrowsError(try CovGOperationFixtures.run(invalid)) {
            guard case StorageDecodingOperationError.invalidStoragePath = $0 else { return XCTFail("Wrong error \($0)") }
        }
        let malformed = StorageDecodingOperation<String>(path: .currentEra, data: Data([1]))
        malformed.codingFactory = invalid.codingFactory
        XCTAssertThrowsError(try CovGOperationFixtures.run(malformed))
    }

    func testPresetResultsAndCancellationPreventDecoding() throws {
        let operations: [BaseOperation<String>] = [StorageDecodingOperation(path: .currentEra), StorageConstantOperation(path: .existentialDeposit)]
        for operation in operations {
            operation.result = .success("cached")
            XCTAssertEqual(try CovGOperationFixtures.run(operation), "cached")
        }
        let cancelled = StorageDecodingOperation<String>(path: .currentEra, data: Data())
        cancelled.cancel()
        cancelled.main()
        XCTAssertNil(cancelled.result)
        let cancelledList = StorageFallbackDecodingListOperation<String>(path: .currentEra)
        cancelledList.cancel()
        cancelledList.main()
        XCTAssertNil(cancelledList.result)
    }

    func testPrimitiveAndCompoundConstantsDecodeAndRejectMissingConfiguration() throws {
        let runtime = try StakingConstantRuntime(values: [.existentialDeposit: 5])
        let primitive = PrimitiveConstantOperation<UInt32>(path: .existentialDeposit)
        primitive.codingFactory = runtime.factory
        XCTAssertEqual(try CovGOperationFixtures.run(primitive), 5)
        let compound = StorageConstantOperation<fearless.StringScaleMapper<UInt32>>(path: .existentialDeposit)
        compound.codingFactory = runtime.factory
        XCTAssertEqual(try CovGOperationFixtures.run(compound).value, 5)
        let missing = PrimitiveConstantOperation<UInt32>(path: .lockUpPeriod)
        missing.codingFactory = runtime.factory
        XCTAssertThrowsError(try CovGOperationFixtures.run(missing))
        XCTAssertThrowsError(try CovGOperationFixtures.run(PrimitiveConstantOperation<UInt32>(path: .existentialDeposit)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(StorageConstantOperation<String>(path: .existentialDeposit)))
    }
}

final class CovGStorageKeyTests: XCTestCase {
    func testUnkeyedAndMapEncodingMatchIndependentStorageKeys() throws {
        let runtime = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let keyFactory = StorageKeyFactory()
        let plain = UnkeyedEncodingOperation(path: .currentEra, storageKeyFactory: keyFactory)
        plain.codingFactory = runtime
        XCTAssertEqual(try CovGOperationFixtures.run(plain), try keyFactory.key(from: .currentEra))
        let account = Data(repeating: 7, count: 32)
        let map = MapKeyEncodingOperation(path: .account, storageKeyFactory: keyFactory, keyParams: [account.toHex(includePrefix: true)])
        map.codingFactory = runtime
        let expected = try keyFactory.createStorageKey(moduleName: "System", storageName: "Account", key: account, hasher: .blake128Concat)
        XCTAssertEqual(try CovGOperationFixtures.run(map), [expected])
        let double = DoubleMapKeyEncodingOperation(
            path: .erasStakers, storageKeyFactory: keyFactory,
            keyParams1: [fearless.StringScaleMapper(value: UInt32(5))], keyParams2: [account.toHex(includePrefix: true)]
        )
        double.codingFactory = runtime
        let expectedDouble = try keyFactory.createStorageKey(
            moduleName: "Staking", storageName: "ErasStakers", key1: Data([5, 0, 0, 0]), hasher1: .twox64Concat,
            key2: account, hasher2: .twox64Concat
        )
        XCTAssertEqual(try CovGOperationFixtures.run(double), [expectedDouble])
    }

    func testNMapEncodingUsesEveryKeyComponent() throws {
        let fixture = try AssetHubStorageFixture()
        let account = Data(repeating: 7, count: 32)
        let expected = try fixture.put(.erasStakersOverview, json: #"{"total":"0","own":"0","nominator_count":"0","page_count":"0"}"#, era: 5, account: account)
        let operation = NMapKeyEncodingOperation(
            path: .erasStakersOverview, storageKeyFactory: StorageKeyFactory(),
            keyParams: [[NMapKeyParam(value: fearless.StringScaleMapper(value: UInt32(5)))], [NMapKeyParam(value: account)]]
        )
        operation.codingFactory = fixture.runtime.factory
        XCTAssertEqual(try CovGOperationFixtures.run(operation), [expected])
    }

    func testKeyEncodersRejectMissingInputsWrongStorageTypeAndBadPaths() throws {
        let runtime = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let factory = StorageKeyFactory()
        XCTAssertThrowsError(try CovGOperationFixtures.run(UnkeyedEncodingOperation(path: .currentEra, storageKeyFactory: factory)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(MapKeyEncodingOperation<String>(path: .currentEra, storageKeyFactory: factory)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(DoubleMapKeyEncodingOperation<String, String>(path: .currentEra, storageKeyFactory: factory)))
        XCTAssertThrowsError(try CovGOperationFixtures.run(NMapKeyEncodingOperation(path: .currentEra, storageKeyFactory: factory)))
        let map = MapKeyEncodingOperation(path: .currentEra, storageKeyFactory: factory, keyParams: ["1"])
        map.codingFactory = runtime
        XCTAssertThrowsError(try CovGOperationFixtures.run(map))
        let double = DoubleMapKeyEncodingOperation(path: .currentEra, storageKeyFactory: factory, keyParams1: ["1"], keyParams2: ["1"])
        double.codingFactory = runtime
        XCTAssertThrowsError(try CovGOperationFixtures.run(double))
        let nmap = NMapKeyEncodingOperation(path: .currentEra, storageKeyFactory: factory, keyParams: [[NMapKeyParam(value: "1")]])
        nmap.codingFactory = runtime
        XCTAssertThrowsError(try CovGOperationFixtures.run(nmap))
        let invalid = UnkeyedEncodingOperation(path: .tokens, storageKeyFactory: factory)
        invalid.codingFactory = runtime
        XCTAssertThrowsError(try CovGOperationFixtures.run(invalid))
    }
}

final class CovGStorageRequestTests: XCTestCase {
    func testDirectAndMapRequestsPreserveKeyOrderAndMissingValues() throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        let key = try fixture.put(.currentEra, json: #""42""#)
        let request = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let wrapper: CompoundOperationWrapper<[StorageResponse<fearless.StringScaleMapper<UInt32>>]> = request.queryItems(
            engine: fixture, keys: { [key] }, factory: { fixture.runtime.factory }, storagePath: .currentEra
        )
        let result = try CovGOperationFixtures.run(wrapper)
        XCTAssertEqual(result.map(\.key), [key])
        XCTAssertEqual(result.first?.value?.value, 42)
        let account = Data(repeating: 1, count: 32)
        let bondedKey = try fixture.put(.controller, json: "\"\(account.toHex(includePrefix: true))\"", account: account)
        let map: CompoundOperationWrapper<[StorageResponse<Data>]> = request.queryItems(
            engine: fixture, keyParams: { [account, Data(repeating: 2, count: 32)] }, factory: { fixture.runtime.factory }, storagePath: .controller
        )
        let mapped = try CovGOperationFixtures.run(map)
        XCTAssertEqual(mapped.count, 2)
        XCTAssertEqual(mapped[0].key, bondedKey)
        XCTAssertEqual(mapped[0].value, account)
        XCTAssertNil(mapped[1].value)
        XCTAssertTrue(fixture.requests.contains { $0.0 == RPCMethod.queryStorageAt })
    }

    func testNMapRequestAndRPCFailurePropagate() throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        let account = Data(repeating: 1, count: 32)
        let key = try fixture.put(.claimedRewards, json: #"["1","2"]"#, era: 5, account: account)
        let request = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let params: [[NMapKeyParamProtocol]] = [
            [NMapKeyParam(value: fearless.StringScaleMapper(value: UInt32(5)))], [NMapKeyParam(value: account)],
        ]
        let wrapper: CompoundOperationWrapper<[StorageResponse<[fearless.StringScaleMapper<UInt32>]>]> = request.queryItems(
            engine: fixture, keyParams: { params }, factory: { fixture.runtime.factory }, storagePath: .claimedRewards
        )
        let response = try CovGOperationFixtures.run(wrapper)
        XCTAssertEqual(response.first?.key, key)
        XCTAssertEqual(response.first?.value?.map(\.value), [1, 2])
        fixture.error = NSError(domain: "CovG.rpc", code: 64)
        let failed: CompoundOperationWrapper<[StorageResponse<String>]> = request.queryItems(
            engine: fixture, keys: { [key] }, factory: { fixture.runtime.factory }, storagePath: .claimedRewards
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(failed)) { XCTAssertEqual(($0 as NSError).code, 64) }
    }

    func testAsyncPerformerSingleMultipleAndCachedStreams() async throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        _ = try fixture.put(.currentEra, json: #""42""#)
        let performer = StorageRequestPerformerDefault(runtimeService: fixture.runtime, connection: fixture)
        let request = CovGSingleRequest(parametersType: .simple, storagePath: .currentEra)
        let single: fearless.StringScaleMapper<UInt32>? = try await performer.performSingle(request)
        XCTAssertEqual(single?.value, 42)
        let stream: AsyncThrowingStream<fearless.StringScaleMapper<UInt32>?, Error> = await performer.performSingle(request, withCacheOptions: .onPerform)
        var values: [UInt32?] = []
        for try await value in stream {
            values.append(value?.value)
        }
        XCTAssertEqual(values, [42])
        let account = Data(repeating: 1, count: 32)
        _ = try fixture.put(.controller, json: "\"\(account.toHex(includePrefix: true))\"", account: account)
        let map = CovGSingleRequest(parametersType: .encodable(param: account), storagePath: .controller)
        let mapped: Data? = try await performer.performSingle(map)
        XCTAssertEqual(mapped, account)
        let multiple = CovGMultipleRequest(parametersType: .multipleEncodable(params: [account, Data(repeating: 2, count: 32)]), storagePath: .controller)
        let many: [Data?] = try await performer.performMultiple(multiple)
        XCTAssertEqual(many, [account, nil])
        let manyStream: AsyncThrowingStream<[Data?], Error> = await performer.performMultiple(multiple, withCacheOptions: .onPerform)
        var batches = 0
        for try await values in manyStream {
            XCTAssertEqual(values, [account, nil]); batches += 1
        }
        XCTAssertEqual(batches, 1)
    }
}

private struct CovGSingleRequest: StorageRequest {
    let parametersType: StorageRequestParametersType
    let storagePath: fearless.StorageCodingPath
}

private struct CovGMultipleRequest: MultipleRequest {
    let parametersType: MultipleStorageRequestParametersType
    let storagePath: fearless.StorageCodingPath
}
