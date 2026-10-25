import BigInt
import XCTest

@testable import SSFAssetManagment
@testable import SSFModels

final class AccountInfoTests: XCTestCase {
    func testAccountInfoInitEthBalance() {
        // act
        let info = AccountInfo(ethBalance: TestData.balance)

        // asset
        XCTAssertEqual(info.nonce, 0)
        XCTAssertEqual(info.consumers, 0)
        XCTAssertEqual(info.providers, 0)
        XCTAssertEqual(info.data, TestData.data)
        XCTAssertEqual(info.data.free, TestData.balance)
    }

    func testAccountInfoInit() {
        // arrange
        let expectedNonce: UInt32 = 1
        let expectedConsumers: UInt32 = 2
        let expectedProviders: UInt32 = 3

        // act
        let info = AccountInfo(
            nonce: expectedNonce,
            consumers: expectedConsumers,
            providers: expectedProviders,
            data: TestData.data
        )

        // asset
        XCTAssertEqual(info.nonce, expectedNonce)
        XCTAssertEqual(info.consumers, expectedConsumers)
        XCTAssertEqual(info.providers, expectedProviders)
        XCTAssertEqual(info.data, TestData.data)
    }

    func testAccountInfoInitOrml() {
        // arrange
        let free = BigUInt("1")
        let reserved = BigUInt("2")
        let frozen = BigUInt("3")
        let ormlAccountInfo = OrmlAccountInfo(free: free, reserved: reserved, frozen: frozen)

        // act
        let info = AccountInfo(ormlAccountInfo: ormlAccountInfo)

        // asset
        XCTAssertEqual(info?.nonce, 0)
        XCTAssertEqual(info?.consumers, 0)
        XCTAssertEqual(info?.providers, 0)
        XCTAssertEqual(info?.data.free, free)
        XCTAssertEqual(info?.data.reserved, reserved)
        XCTAssertEqual(info?.data.frozen, frozen)
        XCTAssertEqual(info?.data.flags, .zero)
    }

    func testAccountInfoFailedInitOrml() {
        // act
        let info = AccountInfo(ormlAccountInfo: nil)

        // asset
        XCTAssertEqual(info, nil)
    }

    func testAccountInfoInitEquilibriumFree() {
        // act
        let info = AccountInfo(equilibriumFree: TestData.balance)

        // asset
        XCTAssertEqual(info?.nonce, 0)
        XCTAssertEqual(info?.consumers, 0)
        XCTAssertEqual(info?.providers, 0)
        XCTAssertEqual(info?.data, TestData.data)
        XCTAssertEqual(info?.data.free, TestData.balance)
        XCTAssertEqual(info?.data.reserved, .zero)
        XCTAssertEqual(info?.data.frozen, .zero)
        XCTAssertEqual(info?.data.flags, .zero)
    }

    func testAccountInfoFailedInitEquilibriumFree() {
        // act
        let info = AccountInfo(equilibriumFree: nil)

        // asset
        XCTAssertEqual(info, nil)
    }

    func testAccountInfoInitAssetAccount() {
        // arrange
        let account = AssetAccount(balance: TestData.balance)

        // act
        let info = AccountInfo(assetAccount: account)

        // asset
        XCTAssertEqual(info?.nonce, 0)
        XCTAssertEqual(info?.consumers, 0)
        XCTAssertEqual(info?.providers, 0)
        XCTAssertEqual(info?.data, TestData.data)
        XCTAssertEqual(info?.data.free, TestData.balance)
        XCTAssertEqual(info?.data.reserved, .zero)
        XCTAssertEqual(info?.data.frozen, .zero)
        XCTAssertEqual(info?.data.flags, .zero)
    }

    func testAccountInfoFailedInitAssetAccount() {
        // act
        let info = AccountInfo(assetAccount: nil)

        // asset
        XCTAssertEqual(info, nil)
    }

    func testAccountInfoNonZeroTrue() {
        // act
        let info = AccountInfo(ethBalance: TestData.balance)

        // asset
        XCTAssertTrue(info.nonZero())
    }

    func testAccountInfoNonZeroFalse() {
        // act
        let info = AccountInfo(ethBalance: BigUInt("0"))

        // asset
        XCTAssertFalse(info.nonZero())
    }

    func testAccountInfoZeroTrue() {
        // act
        let info = AccountInfo(ethBalance: BigUInt("0"))

        // asset
        XCTAssertTrue(info.zero())
    }

    func testAccountInfoZeroFalse() {
        // act
        let info = AccountInfo(ethBalance: TestData.balance)

        // asset
        XCTAssertFalse(info.zero())
    }
}

private extension AccountInfoTests {
    enum TestData {
        static let balance = BigUInt("123")
        static let data = AccountData(ethBalance: TestData.balance)
    }
}
