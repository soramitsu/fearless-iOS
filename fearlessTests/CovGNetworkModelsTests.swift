import BigInt
import Foundation
import SSFUtils
import XCTest
@testable import fearless

#if DEBUG
    private typealias CovGNetworkApiKeys = BlockExplorerApiKeysDebug
#else
    private typealias CovGNetworkApiKeys = BlockExplorerApiKeys
#endif

final class CovGNetworkModelsTests: XCTestCase {
    func testUrlParametersReflectOnlyStringPropertiesAndCodingKeysKeepValues() {
        let parameters = CovGUrlParameters()
        XCTAssertEqual(parameters.urlParameters.map(\.name), ["module", "action"])
        XCTAssertEqual(parameters.urlParameters.map(\.value), ["account", "txlist"])
        let fromString = AnyCodingKey(stringValue: "name")
        XCTAssertEqual(fromString.stringValue, "name")
        XCTAssertNil(fromString.intValue)
        let fromInt = AnyCodingKey(intValue: 4)
        XCTAssertEqual(fromInt.stringValue, "4")
        XCTAssertEqual(fromInt.intValue, 4)
        let copied = AnyCodingKey(fromInt)
        XCTAssertEqual(copied.stringValue, "4")
        XCTAssertEqual(copied.intValue, 4)
    }

    func testPagedKeysRequestOmitsMissingOffsetAndDispatchInfoSumsFees() throws {
        let first = try JSONSerialization.jsonObject(with: JSONEncoder().encode(PagedKeysRequest(key: "0x01"))) as? [Any]
        XCTAssertEqual(first?.count, 2)
        XCTAssertEqual(first?.first as? String, "0x01")
        XCTAssertEqual(first?.last as? Int, 1000)
        let next = try JSONSerialization.jsonObject(with: JSONEncoder().encode(PagedKeysRequest(key: "0x01", count: 5, offset: "0x02"))) as? [Any]
        XCTAssertEqual(next?.count, 3)
        XCTAssertEqual(next?.last as? String, "0x02")
        let info = try JSONDecoder().decode(RuntimeDispatchInfo.self, from: Data(#"""
        {"inclusionFee":{"baseFee":"0x10","lenFee":"0x01","adjustedWeightFee":"0x02"}}
        """#.utf8))
        XCTAssertEqual(info.fee, "19")
        XCTAssertEqual(RuntimeDispatchInfo(feeValue: 42).fee, "42")
        let invalid = try JSONDecoder().decode(FeeDetails.self, from: Data(#"{"baseFee":"zz","lenFee":"0x0","adjustedWeightFee":"0x3"}"#.utf8))
        XCTAssertEqual(invalid.baseFee, 0)
        XCTAssertEqual(invalid.adjustedWeightFee, 3)
    }

    func testJSONRPCErrorContentPrefersProviderDataAndFallsBackToLocalizedTitle() throws {
        let locale = Locale(identifier: "en_US")
        let detailed = try JSONDecoder().decode(JSONRPCError.self, from: Data(#"{"message":"Bad","code":-32000,"data":"Invalid nonce"}"#.utf8))
        let content = detailed.toErrorContent(for: locale)
        XCTAssertEqual(content.title, "Bad")
        XCTAssertEqual(content.message, "Invalid nonce (code -32000)")
        let plain = try JSONDecoder().decode(JSONRPCError.self, from: Data(#"{"message":"Bad","code":7}"#.utf8))
        let fallback = plain.toErrorContent(for: locale)
        XCTAssertEqual(fallback.title, R.string.localizable.operationErrorTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(fallback.message, "Bad (code 7)")
    }

    func testSmallSubstrateAndSubscanModelsDecodeTheirShapes() throws {
        XCTAssertEqual(EventCodingPath.extrisicSuccess, EventCodingPath(moduleName: "System", eventName: "ExtrinsicSuccess"))
        XCTAssertEqual(EventCodingPath.extrinsicFailed.eventName, "ExtrinsicFailed")
        XCTAssertEqual(EventCodingPath.balanceDeposit.moduleName, "Balances")
        XCTAssertEqual(EventCodingPath.treasuryDeposit.moduleName, "Treasury")
        XCTAssertEqual(try JSONDecoder().decode([ExtrinisicIndexWrapper].self, from: Data(#"["12-4","7"]"#.utf8)).map(\.value), [4, 7])
        XCTAssertThrowsError(try JSONDecoder().decode(ExtrinisicIndexWrapper.self, from: Data(#""12-x""#.utf8)))
        let status = try JSONDecoder().decode(SubscanStatusData<String>.self, from: Data(#"{"code":10004,"message":"Limited"}"#.utf8))
        XCTAssertFalse(status.isSuccess)
        let error = SubscanError(statusData: status)
        XCTAssertEqual(error.code, 10004)
        XCTAssertEqual(error.message, "Limited")
        XCTAssertEqual(ReferralMethodType(fromRawValue: "unreserve"), .unbond)
        XCTAssertEqual(ReferralMethodType(fromRawValue: "setReferrer"), .setReferrer)
        XCTAssertEqual(ReferralMethodType(fromRawValue: "unknown"), .bond)
        XCTAssertEqual(try JSONDecoder().decode(TreasuryDepositEvent.self, from: Data(#"["150"]"#.utf8)).amount, 150)
        let lease = try JSONDecoder().decode(ParachainSlotLease.self, from: Data(#"["AQI=","9"]"#.utf8))
        XCTAssertEqual(lease.accountId, Data([1, 2]))
        XCTAssertEqual(lease.amount, 9)
    }

    func testBlockExplorerKeysMapSupportedChainsOnly() {
        let mapping: [(String, BlockExplorerApiKey)] = [
            ("1", .etherscan), ("5", .etherscan), ("137", .polygonscan), ("56", .bscscan), ("97", .bscscan), ("195", .oklink), ("10", .opMainnet),
        ]
        for (chainId, expected) in mapping {
            XCTAssertEqual(BlockExplorerApiKey(chainId: chainId), expected)
        }
        XCTAssertNil(BlockExplorerApiKey(chainId: "42"))
        let saved = CovGNetworkApiKeys.polygonscanApiKey
        CovGNetworkApiKeys.polygonscanApiKey = "cov-g-polygon"
        defer { CovGNetworkApiKeys.polygonscanApiKey = saved }
        XCTAssertEqual(BlockExplorerApiKey.polygonscan.value, "cov-g-polygon")
        XCTAssertEqual(BlockExplorerApiKey.etherscan.value, CovGNetworkApiKeys.etherscanApiKey)
        XCTAssertEqual(BlockExplorerApiKey.bscscan.value, CovGNetworkApiKeys.bscscanApiKey)
        XCTAssertEqual(BlockExplorerApiKey.oklink.value, CovGNetworkApiKeys.oklinkApiKey)
        XCTAssertEqual(BlockExplorerApiKey.opMainnet.value, CovGNetworkApiKeys.opMainnetApiKey)
    }
}

private final class CovGUrlParameters: NetworkRequestUrlParameters {
    let module = "account"
    let action = "txlist"
    let page = 3
}
