import BigInt
import Foundation
import SSFUtils
import TonAPI
import TonSwift
import XCTest
@testable import fearless

final class CovGSmallTypesTests: XCTestCase {
    func testErasStakersKeysRoundTripThroughScale() throws {
        let account = Data(repeating: 3, count: 32)
        let pagedEncoder = ScaleEncoder()
        try UInt32(7).encode(scaleEncoder: pagedEncoder)
        try account.encode(scaleEncoder: pagedEncoder)
        try UInt32(2).encode(scaleEncoder: pagedEncoder)
        let paged = try ErasStakersPagedKey(scaleDecoder: ScaleDecoder(data: pagedEncoder.encode()))
        XCTAssertEqual(paged.era, 7)
        XCTAssertEqual(paged.accountId, account)
        XCTAssertEqual(paged.page, 2)
        let reencoded = ScaleEncoder()
        try paged.encode(scaleEncoder: reencoded)
        XCTAssertEqual(reencoded.encode(), pagedEncoder.encode())

        let overviewEncoder = ScaleEncoder()
        try UInt32(9).encode(scaleEncoder: overviewEncoder)
        try account.encode(scaleEncoder: overviewEncoder)
        let overview = try ErasStakersOverviewKey(scaleDecoder: ScaleDecoder(data: overviewEncoder.encode()))
        XCTAssertEqual(overview.era, 9)
        XCTAssertEqual(overview.accountId, account)
        let overviewOut = ScaleEncoder()
        try overview.encode(scaleEncoder: overviewOut)
        XCTAssertEqual(overviewOut.encode(), overviewEncoder.encode())
    }

    func testBytesCodableAndExposurePagesCombineValues() throws {
        let bytes = try JSONDecoder().decode(fearless.BytesCodable.self, from: Data(#"["1","2","255"]"#.utf8))
        XCTAssertEqual(bytes.wrappedValue, Data([1, 2, 255]))
        XCTAssertEqual(try JSONDecoder().decode(fearless.BytesCodable.self, from: JSONEncoder().encode(bytes)), bytes)
        XCTAssertThrowsError(try JSONDecoder().decode(fearless.BytesCodable.self, from: Data(#""text""#.utf8)))
        let first = try JSONDecoder().decode(ValidatorExposurePage.self, from: Data(#"{"others":[],"pageTotal":"5"}"#.utf8))
        let second = try JSONDecoder().decode(ValidatorExposurePage.self, from: Data(#"{"others":[],"pageTotal":"7"}"#.utf8))
        let combined = first + second
        XCTAssertEqual(combined.pageTotal, 12)
        XCTAssertTrue(combined.others.isEmpty)
        let exposures = try JSONDecoder().decode([IndividualExposure].self, from: Data(#"[{"who":"AQI=","value":"3"},{"who":"0x0304","value":"4"}]"#.utf8))
        XCTAssertEqual(exposures.map(\.who), [Data([1, 2]), Data([3, 4])])
        XCTAssertEqual(exposures.map(\.value), [3, 4])
        let chunk = try JSONDecoder().decode(UnlockChunk.self, from: Data(#"["5","10"]"#.utf8))
        XCTAssertEqual(chunk.era, 5)
        XCTAssertEqual(chunk.value, 10)
        let keyed = try JSONDecoder().decode(UnlockChunk.self, from: Data(#"{"era":"6","value":"11"}"#.utf8))
        XCTAssertEqual(keyed.era, 6)
    }

    func testTonAddressHelpersParseRawAddressesAndAccountIds() throws {
        let hash = Data(repeating: 0x11, count: 32)
        let raw = "0:" + String(repeating: "11", count: 32)
        XCTAssertEqual(try TonAddressFactory.accountId(from: raw), hash)
        XCTAssertThrowsError(try TonAddressFactory.accountId(from: "invalid"))
        let address = try hash.asTonAddress()
        XCTAssertEqual(address.toRaw(), raw)
        let json: [String: Any] = [
            "address": raw, "balance": 42, "status": "active", "name": "Wallet", "icon": "https://ton.invalid/icon",
            "is_suspended": false, "is_wallet": true, "last_activity": 1, "get_methods": [],
        ]
        let api = try JSONDecoder().decode(Components.Schemas.Account.self, from: JSONSerialization.data(withJSONObject: json))
        let account = try TonAccount(account: api)
        XCTAssertEqual(account.address.toRaw(), raw)
        XCTAssertEqual(account.balance, 42)
        XCTAssertEqual(account.status, "active")
        XCTAssertEqual(account.name, "Wallet")
        XCTAssertEqual(account.isSuspended, false)
        XCTAssertTrue(account.isWallet)
    }

    func testPriceProviderFactoryUpdatesExistingSourceAndReportsFollowUp() throws {
        let factory = PriceProviderFactory()
        XCTAssertFalse(factory.pricesProviderNeedsFollowUpFetch())
        factory.updatePricesProvider(currencies: [.defaultCurrency()], chainAssets: [])
        XCTAssertFalse(factory.pricesProviderNeedsFollowUpFetch())
        let provider = factory.getPricesProvider(currencies: [.defaultCurrency()], chainAssets: [])
        let again = factory.getPricesProvider(currencies: nil, chainAssets: [])
        XCTAssertTrue(provider === again)
        factory.updatePricesProvider(currencies: nil, chainAssets: [])
        XCTAssertFalse(factory.pricesProviderNeedsFollowUpFetch())
    }
}
