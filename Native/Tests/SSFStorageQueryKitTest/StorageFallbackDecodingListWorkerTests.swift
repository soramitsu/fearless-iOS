import BigInt
import MocksBasket
import XCTest

@testable import SSFStorageQueryKit

final class StorageFallbackDecodingListWorkerTests: XCTestCase {
    func testExample() async throws {
        let codingFactory = try await PolkadotRuntimeProvider()
            .buildRuntimeProvider()
            .fetchCoderFactory()
        let data = try Data(hexStringSSF: "0x02b55b1200")
        let dataList = [data]
        let worker = StorageFallbackDecodingListWorker<ValidatorPrefs>(
            codingFactory: codingFactory,
            path: StoragePathMock.custom(moduleName: "staking", itemName: "erasValidatorPrefs"),
            dataList: dataList
        )
        let decoded = try worker.performDecoding()
        let extectedResult = ValidatorPrefs(
            commission: BigUInt(stringLiteral: "77000000"),
            blocked: false
        )
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first, extectedResult)
    }
}
