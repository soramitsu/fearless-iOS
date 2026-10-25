import BigInt
import SSFModels
import XCTest

@testable import SSFAssetManagment

final class EquilibriumAccountDataTests: XCTestCase {
    func testEquilibriumAccountInfoDecode() throws {
        // act
        let info = try JSONDecoder().decode(
            EquilibriumAccountInfo.self,
            from: TestData.accountInfoJson
        )

        if case let .v0data(info) = info.data {
            XCTAssertNotNil(info)
        }
    }

    func testEquilibriumAccountDataDecode() throws {
        // act
        let positiveData = try JSONDecoder().decode(
            EquilibriumAccountData.self,
            from: TestData.accountDataJson
        )

        if case let .v0data(info) = positiveData {
            XCTAssertNotNil(info)
            XCTAssertNotNil(info.mapBalances())
        }
    }
}

extension EquilibriumAccountDataTests {
    enum TestData {
        static let accountInfoJson = """
        {
        "nonce": "123",
        "consumers": "123",
        "providers": "123",
        "sufficients": "123",
        "data": [ "V0", { "balance": [ [ "123", [ "Positive", "123" ] ] ] } ]
        }

        """.data(using: .utf8)!

        static let accountDataJson = """
        [
         "V0", { "balance": [ [ "123", [ "Positive", "123" ] ] ] }
        ]
        """.data(using: .utf8)!
    }
}
