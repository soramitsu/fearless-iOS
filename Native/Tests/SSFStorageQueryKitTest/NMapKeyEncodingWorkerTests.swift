import MocksBasket
import SSFCrypto
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import SSFStorageQueryKit

final class NMapKeyEncodingWorkerTests: XCTestCase {
    private var codingFactory: RuntimeCoderFactoryProtocol!

    override func setUp() async throws {
        try await super.setUp()
        try await buildRuntimeProvider()
    }

    func testNMapEntryType() async throws {
        let account = try AddressFactory.accountId(
            from: "1zugcag7cJVBtVRnFxv5Qftn7xKAnR6YJ9x4x3XLgGgmNnS",
            chainFormat: .sfSubstrate(0)
        )
        let worker = NMapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: StoragePathMock.custom(moduleName: "Staking", itemName: "ErasValidatorPrefs"),
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [[
                [NMapKeyParam(value: "1353")],
                [NMapKeyParam(value: account)],
            ]]
        )

        let keys = try worker.performEncoding()

        let expectedModuleNaneKey = "5f3e4907f716ac89b6347d15ececedca"
        let expectedItemNameKey = "682db92dde20a10d96d00ff0e9e221c0"
        let expectedParamKey1 = "176ef2fb941d646249050000"
        let expectedParamKey2 =
            "00339ea96e66b59c2c2a55b5b7e13a772e0b693c3b351d2fb5e5b4da18ac379ebdb2f1f2e7559776"
        let expectedKey = [
            expectedModuleNaneKey,
            expectedItemNameKey,
            expectedParamKey1,
            expectedParamKey2,
        ].joined()

        let keyResult = keys.first?.toHex()

        XCTAssertEqual(keys.count, 1)
        XCTAssertEqual(expectedKey, keyResult)
    }

    /**
     Test for NMapKeyEncodingWorker

     testing entrie type is equal to entrie from storage path
     guard case let .nMap(nMapEntry) = entry.type
     */
    func testThrows1() async throws {
        let account = try AddressFactory.accountId(
            from: "12zcF9m6QpUaGeJrrKYRGubZuxa9YyuVRTjpXGyVNsCpzspY",
            chainFormat: .sfSubstrate(0)
        )
        let worker = NMapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: StoragePathMock.custom(moduleName: "Staking", itemName: "currentPlannedSession"),
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [[
                [NMapKeyParam(value: account)],
                [NMapKeyParam(value: "1353")],
            ]]
        )

        do {
            let _ = try worker.performEncoding()
            XCTFail("Test should to throw error")
        } catch {
            XCTAssertTrue(true)
        }
    }

    /**
     Test for NMapKeyEncodingWorker

     testing entries count and params count
     guard keyEntries.count == keyParams.count
     */
    func testThrows2() async throws {
        let account = try AddressFactory.accountId(
            from: "12zcF9m6QpUaGeJrrKYRGubZuxa9YyuVRTjpXGyVNsCpzspY",
            chainFormat: .sfSubstrate(0)
        )
        let worker = NMapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: StoragePathMock.custom(moduleName: "Staking", itemName: "ErasValidatorPrefs"),
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [[
                [NMapKeyParam(value: account)],
            ]]
        )

        do {
            let _ = try worker.performEncoding()
            XCTFail("Test should to throw error")
        } catch {
            XCTAssertTrue(true)
        }
    }

    /**
     Test for NMapKeyEncodingWorker

     testing error throwing for param encoding
     try param.encode(encoder: codingFactory.createEncoder(), type: keyEntries[index])
     */
    func testThrows3() async throws {
        let worker = NMapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: StoragePathMock.custom(moduleName: "Staking", itemName: "ErasValidatorPrefs"),
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [[
                [NMapKeyParam(value: 123)],
            ]]
        )

        do {
            let _ = try worker.performEncoding()
            XCTFail("Test should to throw error")
        } catch {
            XCTAssertTrue(true)
        }
    }

    private func buildRuntimeProvider() async throws {
        guard codingFactory == nil else {
            return
        }
        codingFactory = try await PolkadotRuntimeProvider()
            .buildRuntimeProvider()
            .fetchCoderFactory()
    }
}
