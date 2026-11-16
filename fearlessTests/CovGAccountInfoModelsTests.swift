import BigInt
import Foundation
import SSFUtils
import XCTest
@testable import fearless

final class CovGAccountInfoModelsTests: XCTestCase {
    func testOptionalSourcesMapIntoAccountDataAndDerivedBalances() throws {
        XCTAssertNil(AccountInfo(ormlAccountInfo: nil))
        XCTAssertNil(AccountInfo(equilibriumFree: nil))
        XCTAssertNil(AccountInfo(assetAccount: nil))
        let orml = try JSONDecoder().decode(OrmlAccountInfo.self, from: Data(#"{"free":"10","reserved":"4","frozen":"12"}"#.utf8))
        let fromOrml = try XCTUnwrap(AccountInfo(ormlAccountInfo: orml))
        XCTAssertEqual(fromOrml.data.total, 14)
        XCTAssertEqual(fromOrml.data.locked, 12)
        XCTAssertEqual(fromOrml.data.stakingAvailable, 0)
        XCTAssertEqual(fromOrml.data.sendAvailable, 0)
        XCTAssertTrue(fromOrml.nonZero())
        XCTAssertFalse(fromOrml.isZero())
        let fromEquilibrium = try XCTUnwrap(AccountInfo(equilibriumFree: 0))
        XCTAssertTrue(fromEquilibrium.isZero())
        XCTAssertEqual(fromEquilibrium.data.flags, 0)
        let asset = try JSONDecoder().decode(AssetAccount.self, from: Data(#"{"balance":"9"}"#.utf8))
        let fromAsset = try XCTUnwrap(AccountInfo(assetAccount: asset))
        XCTAssertEqual(fromAsset.data.free, 9)
        XCTAssertEqual(fromAsset.data.sendAvailable, 9)
    }

    func testAccountDataDecodesLegacyFrozenFieldsAndPlainNumbers() throws {
        let legacy = try JSONDecoder().decode(AccountData.self, from: Data(#"""
        {"free":"100","reserved":"5","miscFrozen":"30","feeFrozen":"40"}
        """#.utf8))
        XCTAssertEqual(legacy.frozen, 40)
        XCTAssertEqual(legacy.flags, 0)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]
        XCTAssertEqual(encoded.map { Set($0.keys) }, ["free", "reserved", "frozen", "flags"])
        XCTAssertThrowsError(try JSONDecoder().decode(AccountData.self, from: Data(#"{"free":"1","reserved":"2"}"#.utf8)))
    }

    func testEquilibriumBalancesMapByCurrencyAndRejectUnknownShapes() throws {
        let json = #"""
        {"nonce":"1","consumers":"0","providers":"1","sufficients":"0",
        "data":["V0",{"balance":[["7",["Positive","53"]],["8",["Positive","2"]]]}]}
        """#
        let info = try JSONDecoder().decode(EquilibriumAccountInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.nonce, 1)
        XCTAssertEqual(info.data.info?.mapBalances(), ["7": 53, "8": 2])
        XCTAssertThrowsError(try JSONDecoder().decode(EquilibriumAccountData.self, from: Data(#"["V1",{}]"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(EquilibruimPositive.self, from: Data(#"["Negative","1"]"#.utf8)))
    }

    func testScaleDecodingReadsCountersAndCompactBalances() throws {
        let bytes = Data([1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 0x14, 0x18])
        let info = try AccountInfo(scaleDecoder: ScaleDecoder(data: bytes))
        XCTAssertEqual(info.nonce, 1)
        XCTAssertEqual(info.consumers, 2)
        XCTAssertEqual(info.providers, 3)
        XCTAssertEqual(info.data.free, 5)
        XCTAssertEqual(info.data.reserved, 6)
        XCTAssertEqual(info.data.frozen, 0)
        XCTAssertThrowsError(try AccountInfo(scaleDecoder: ScaleDecoder(data: Data([1, 0]))))
    }
}
