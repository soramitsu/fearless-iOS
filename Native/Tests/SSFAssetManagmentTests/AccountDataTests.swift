import BigInt
import SSFModels
import SSFUtils
import XCTest

@testable import SSFAssetManagment

final class AccountDataTests: XCTestCase {
    func testAccountDataInit() {
        // act
        let data = AccountData(
            free: TestData.balance,
            reserved: TestData.balance,
            frozen: TestData.balance,
            flags: nil
        )

        // asset
        XCTAssertEqual(data.free, TestData.balance)
        XCTAssertEqual(data.reserved, TestData.balance)
        XCTAssertEqual(data.frozen, TestData.balance)
        XCTAssertEqual(data.flags, .zero)
    }

    func testAccountDataDecode() throws {
        // act
        let encodedData = try JSONEncoder().encode(TestData.accountDataMock)
        let decodedData = try JSONDecoder().decode(AccountData.self, from: encodedData)

        // assert
        XCTAssertEqual(decodedData, TestData.accountDataMock)
    }

    func testAccountDataTotal() throws {
        // assert
        XCTAssertEqual(TestData.accountDataMock.total, TestData.balance)
    }

    func testAccountDataFrozen() throws {
        // assert
        XCTAssertEqual(TestData.accountDataMock.locked, TestData.zeroBalance)
    }

    func testAccountDataStackingAvailable() throws {
        // assert
        XCTAssertEqual(TestData.accountDataMock.stakingAvailable, TestData.balance)
    }

    func testAccountDataSendAvailable() throws {
        // assert
        XCTAssertEqual(TestData.accountDataMock.sendAvailable, TestData.balance)
    }
}

private extension AccountDataTests {
    enum TestData {
        static let balance = BigUInt("123")
        static let zeroBalance = BigUInt("0")
        static let accountDataMock = AccountData(ethBalance: TestData.balance)
    }
}
