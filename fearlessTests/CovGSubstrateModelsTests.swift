import BigInt
@testable import fearless
import SSFUtils
import UIKit
import XCTest

final class CovGSubstrateModelsTests: XCTestCase {
    func testMultiSignerAndCrowdloanLastContributionVariantsRoundTrip() throws {
        let data = Data([1, 2, 255])
        for signer in [MultiSigner.ed25519(data), .sr25519(data), .ecdsa(data)] {
            XCTAssertEqual(try JSONDecoder().decode(MultiSigner.self, from: JSONEncoder().encode(signer)), signer)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(MultiSigner.self, from: Data(#"["Unknown",["1"]]"#.utf8)))
        for contribution in [CrowdloanLastContribution.never, .preEnding(value: 5), .ending(blockNumber: 7)] {
            XCTAssertEqual(try JSONDecoder().decode(CrowdloanLastContribution.self, from: JSONEncoder().encode(contribution)), contribution)
        }
        for json in [#"["Unknown"]"#, #"["PreEnding","bad"]"#, #"["Ending","bad"]"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(CrowdloanLastContribution.self, from: Data(json.utf8)))
        }
    }

    func testCrowdloanFundsDecodeBothIndexVersionsAndEncodeAllFields() throws {
        for index in ["trieIndex", "fundIndex"] {
            let json = """
            {"depositor":"AQI=","deposit":"10","raised":"20","end":"30","cap":"40", "lastContribution":["Never",null],
            "firstPeriod":"5","lastPeriod":"8","\(index)":"7"}
            """
            let funds = try JSONDecoder().decode(CrowdloanFunds.self, from: Data(json.utf8))
            XCTAssertEqual(funds.depositor, Data([1, 2]))
            XCTAssertEqual(funds.deposit, 10)
            XCTAssertEqual(funds.raised, 20)
            XCTAssertEqual(funds.end, 30)
            XCTAssertEqual(funds.cap, 40)
            XCTAssertEqual(funds.firstPeriod, 5)
            XCTAssertEqual(funds.lastPeriod, 8)
            XCTAssertEqual(funds.lastContribution, .never)
            XCTAssertEqual(funds.trieOrFundIndex, index == "trieIndex" ? .trieIndex(7) : .fundIndex(7))
            let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(funds)) as? [String: Any])
            XCTAssertEqual(encoded["raised"] as? String, "20")
            XCTAssertEqual(encoded[index] as? Int, 7)
            XCTAssertEqual(try funds.trieOrFundIndex.scaleEncoded(), Data([7, 0, 0, 0]))
        }
        for json in ["{}", #"{"trieIndex":"bad"}"#, #"{"fundIndex":"bad"}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(TrieOrFundIndex.self, from: Data(json.utf8)))
        }
    }

    func testAssetStatusControlsLiquidFrozenAndBlockedBalances() throws {
        for status in ["Liquid", "Frozen", "Blocked"] {
            let json = "{\"balance\":\"53\",\"status\":[\"\(status)\",null]}"
            let account = try JSONDecoder().decode(AssetAccountInfo.self, from: Data(json.utf8))
            XCTAssertEqual(account.balance, 53)
            XCTAssertEqual(account.locked, status == "Liquid" ? 0 : 53)
            XCTAssertEqual(account.frozen, status == "Frozen" ? 53 : 0)
            XCTAssertEqual(account.blocked, status == "Blocked" ? 53 : 0)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(AssetStatus.self, from: Data(#"["Unknown"]"#.utf8)))
        for status in ["Live", "Frozen", "Destroying"] {
            let json = "{\"minBalance\":\"5\",\"isSufficient\":true,\"status\":[\"\(status)\",null]}"
            let details = try JSONDecoder().decode(AssetDetails.self, from: Data(json.utf8))
            XCTAssertEqual(details.minBalance, 5)
            XCTAssertTrue(details.isSufficient)
            XCTAssertEqual(details.isFrozen, status != "Live")
        }
        for frozen in [false, true] {
            let json = "{\"minBalance\":\"5\",\"isSufficient\":false,\"isFrozen\":\(frozen)}"
            let details = try JSONDecoder().decode(AssetDetails.self, from: Data(json.utf8))
            XCTAssertEqual(details.isFrozen, frozen)
            XCTAssertEqual(details.status, frozen ? .frozen : .live)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(AssetDetailsV2.Status.self, from: Data(#"["Unknown"]"#.utf8)))
    }

    func testBalanceLocksPreserveIdentifierAmountsAndReasons() throws {
        for reason in ["Fee", "Misc", "All"] {
            let json = "{\"id\":[\"32\",\"116\",\"101\",\"115\",\"116\",\"32\"],\"amount\":\"53\",\"reasons\":[\"\(reason)\",null]}"
            let lock = try JSONDecoder().decode(BalanceLock.self, from: Data(json.utf8))
            XCTAssertEqual(lock.displayId, "test")
            XCTAssertEqual(lock.lockType, "test")
            XCTAssertEqual(lock.amount, 53)
            XCTAssertEqual(lock.reasons.rawValue, reason)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(LockReason.self, from: Data(#"["Unknown"]"#.utf8)))
    }

    func testChainDataTextHashAndImageProjections() throws {
        let text = ChainData.raw(data: Data("name".utf8))
        XCTAssertEqual(text.stringValue, "name")
        XCTAssertEqual(text.dataValue, Data("name".utf8))
        XCTAssertNil(text.imageValue)
        let bytes = Data(repeating: 1, count: 32)
        let hash = H256(value: bytes)
        for value in [ChainData.blakeTwo256(data: hash), .keccak256(data: hash), .sha256(data: hash), .shaThree256(data: hash)] {
            XCTAssertEqual(value.stringValue, "0x" + String(repeating: "01", count: 32))
            XCTAssertEqual(value.dataValue, bytes)
            XCTAssertNil(value.imageValue)
        }
        XCTAssertNil(ChainData.none.stringValue)
        XCTAssertNil(ChainData.none.dataValue)
        let imageData = try XCTUnwrap(UIImage(systemName: "star")?.pngData())
        XCTAssertNotNil(ChainData.raw(data: imageData).imageValue)
    }

    func testIdentityAndSuperIdentitySupportContainerShapes() throws {
        let value = ChainData.raw(data: Data("name".utf8))
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: .fragmentsAllowed)
        let info: [String: Any] = ["info": ["display": encoded, "additional": [[encoded, encoded]]]]
        for payload in [info as Any, [info] as Any] {
            let identity = try JSONDecoder().decode(IdentityResponse.self, from: JSONSerialization.data(withJSONObject: payload))
            XCTAssertEqual(identity.identity.info.display?.stringValue, "name")
            XCTAssertEqual(identity.identity.info.additional?.first?.field.stringValue, "name")
            XCTAssertEqual(identity.identity.info.additional?.first?.value.stringValue, "name")
        }
        for data in [value, ChainData.none] {
            let payload: [Any] = try ["AQI=", JSONSerialization.jsonObject(with: JSONEncoder().encode(data), options: .fragmentsAllowed)]
            let identity = try JSONDecoder().decode(SuperIdentity.self, from: JSONSerialization.data(withJSONObject: payload))
            XCTAssertEqual(identity.parentAccountId, Data([1, 2]))
            XCTAssertEqual(identity.name, data.stringValue)
            let roundTrip = try JSONDecoder().decode(SuperIdentity.self, from: JSONEncoder().encode(identity))
            XCTAssertEqual(roundTrip.name, identity.name)
        }
    }

    func testKmmPathsClassifyTransfersSwapsLiquidityAndReferrals() {
        XCTAssertTrue(KmmCallCodingPath.transfer.isTransfer)
        XCTAssertTrue(KmmCallCodingPath.transferKeepAlive.isTransfer)
        XCTAssertFalse(KmmCallCodingPath.swap.isTransfer)
        XCTAssertTrue(KmmCallCodingPath.swap.isSwap)
        XCTAssertTrue(KmmCallCodingPath.migration.isMigration)
        XCTAssertTrue(KmmCallCodingPath.depositLiquidity.isDepositLiquidity)
        XCTAssertTrue(KmmCallCodingPath.withdrawLiquidity.isWithdrawLiquidity)
        for path in [KmmCallCodingPath.setReferral, .bondReferralBalance, .unbondReferralBalance] {
            XCTAssertTrue(path.isReferral)
        }
        XCTAssertFalse(KmmCallCodingPath.batchAllUtility.isReferral)
        XCTAssertEqual(KmmCallCodingPath.batchUtility.callName, "batch")
        XCTAssertEqual(KmmCallCodingPath.batchAllUtility.moduleName, "utility")
    }
}
