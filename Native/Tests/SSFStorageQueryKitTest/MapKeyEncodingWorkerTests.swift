import MocksBasket
import SSFCrypto
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import SSFStorageQueryKit

final class MapKeyEncodingWorkerTests: XCTestCase {
    private var codingFactory: RuntimeCoderFactoryProtocol!

    override func setUp() async throws {
        try await super.setUp()
        try await buildRuntimeProvider()
    }

    func testNMapEntryType() async throws {
        let worker = MapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: StoragePathMock.custom(moduleName: "Crowdloan", itemName: "Funds"),
            storageKeyFactory: StorageKeyFactory(),
            keyParams: ["2094"]
        )

        let keys = try worker.performEncoding()

        let expectedModuleNaneKey = "3d9cad2baf702e20b136f4c8900cd802"
        let expectedItemNameKey = "b6f9671a19ef28ecb1e331fea3029098"
        let expectedParamKey = "071ceff5b0f64d362e080000"
        let expectedKey = [expectedModuleNaneKey, expectedItemNameKey, expectedParamKey].joined()

        let keyResult = keys.first?.toHex()

        XCTAssertEqual(keys.count, 1)
        XCTAssertEqual(expectedKey, keyResult)
    }

    func testThrows() async throws {
        let account = try AddressFactory.accountId(
            from: "12zcF9m6QpUaGeJrrKYRGubZuxa9YyuVRTjpXGyVNsCpzspY",
            chainFormat: .sfSubstrate(0)
        )
        let worker = MapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: StoragePathMock.custom(moduleName: "Balances", itemName: "InactiveIssuance"),
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [account]
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
