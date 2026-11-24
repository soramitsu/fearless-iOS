import XCTest
import BigInt
import SSFModels
import SSFUtils
@testable import fearless

enum CovJWcCallJSON {
    /// A call as the runtime decodes it: `[Module, [call_name, {arguments}]]`.
    static func call(_ module: String, _ name: String, _ args: [String: JSON]) -> JSON {
        .arrayValue([.stringValue(module), .arrayValue([.stringValue(name), .dictionaryValue(args)])])
    }

    static func account(_ byte: UInt8) -> JSON {
        .arrayValue([.stringValue("Id"), .stringValue(Data(repeating: byte, count: 32).toHex(includePrefix: true))])
    }

    static let text = WalletConnectSubstrateCallText(address: { _ in "ADDR" }, nativeAmount: { "\($0) NAT" })
}

final class CovJWcSubstrateCallTextTests: XCTestCase {
    func testScalarsEnumsListsAndMapsAreShownAsDecoded() {
        let call = RuntimeCall(moduleName: "Example", callName: "store", args: JSON.dictionaryValue([
            "a_signed": .signedIntValue(-5),
            "b_double": .doubleValue(1.5),
            "c_flag": .boolValue(true),
            "d_empty_list": .arrayValue([]),
            "e_empty_map": .dictionaryValue([:]),
            "f_unit_case": .arrayValue([.stringValue("Any"), .null]),
            "g_enum_parts": .arrayValue([
                .stringValue("Limited"),
                .dictionaryValue(["weight": .unsignedIntValue(10), "proof": .unsignedIntValue(2)])
            ]),
            "h_items": .arrayValue([.dictionaryValue(["x": .unsignedIntValue(1)]), .stringValue("plain")]),
            "i_nested_map": .dictionaryValue(["inner": .boolValue(false)]),
            "j_account": .arrayValue([.stringValue("Address32"), .stringValue(Data(repeating: 7, count: 32).toHex(includePrefix: true))])
        ]))
        XCTAssertEqual(CovJWcCallJSON.text.text(forArgumentsOf: call), [
            "a_signed: -5",
            "b_double: 1.5",
            "c_flag: true",
            "d_empty_list: []",
            "e_empty_map: {}",
            "f_unit_case: Any",
            "g_enum_parts:",
            "  Limited:",
            "    proof: 2",
            "    weight: 10",
            "h_items:",
            "  1.",
            "     x: 1",
            "  2. plain",
            "i_nested_map:",
            "  inner: false",
            "j_account: ADDR"
        ].joined(separator: "\n"))
        XCTAssertTrue(CovJWcCallJSON.text.fits(call))
        XCTAssertTrue(CovJWcCallJSON.text.summaryLines(for: call).isEmpty)
    }

    func testCallsInsideListsAreNumberedWithTheirArguments() {
        let call = RuntimeCall(moduleName: "Example", callName: "nest", args: JSON.dictionaryValue([
            "groups": .arrayValue([
                .arrayValue([
                    CovJWcCallJSON.call("System", "remark", ["remark": .stringValue("0x01")]),
                    CovJWcCallJSON.call("System", "remark_with_event", ["remark": .stringValue("0x02")])
                ]),
                .unsignedIntValue(5)
            ]),
            "wrapped": .arrayValue([CovJWcCallJSON.call("System", "remark", ["remark": .stringValue("0x00")]), .unsignedIntValue(3)])
        ]))
        let arguments = [
            "groups:",
            "  1.",
            "     1. System.remark",
            "        remark: 0x01",
            "     2. System.remark_with_event",
            "        remark: 0x02",
            "  2. 5",
            "wrapped:",
            "  1.",
            "     System.remark",
            "       remark: 0x00",
            "  2. 3"
        ].joined(separator: "\n")
        let summary = ["1 × System.remark_with_event", "2 × System.remark"]

        XCTAssertEqual(CovJWcCallJSON.text.text(forArgumentsOf: call), arguments)
        XCTAssertEqual(CovJWcCallJSON.text.summaryLines(for: call), summary)
        let rows = CovJWcCallJSON.text.rows(for: call, locale: CovJWcFixture.locale)
        XCTAssertEqual(rows.map(\.kind), [.call, .calls, .arguments])
        XCTAssertEqual(rows.map(\.value), ["Example.nest", summary.joined(separator: "\n"), arguments])
        XCTAssertEqual(WalletConnectSubstrateCallText.innerCalls(of: call).map(\.name), ["System.remark", "System.remark_with_event", "System.remark"])
    }

    func testArgumentsThatAreNotAMapAreShownAsAValue() {
        let list = RuntimeCall(moduleName: "Example", callName: "raw", args: JSON.arrayValue([.unsignedIntValue(1), .unsignedIntValue(2)]))
        let text = RuntimeCall(moduleName: "Example", callName: "raw", args: JSON.stringValue("payload"))
        XCTAssertEqual(CovJWcCallJSON.text.text(forArgumentsOf: list), "[1, 2]")
        XCTAssertEqual(CovJWcCallJSON.text.text(forArgumentsOf: text), "payload")
        let rows = CovJWcCallJSON.text.rows(for: list, locale: CovJWcFixture.locale)
        XCTAssertEqual(rows.map(\.kind), [.call, .arguments])
        let empty = RuntimeCall(moduleName: "Example", callName: "noop", args: JSON.dictionaryValue([:]))
        XCTAssertEqual(CovJWcCallJSON.text.rows(for: empty, locale: CovJWcFixture.locale).map(\.kind), [.call])
    }

    func testSummaryGroupsAssetsAccountsAndAmountsPerModule() {
        let batch = RuntimeCall(moduleName: "Utility", callName: "batch", args: JSON.dictionaryValue(["calls": .arrayValue([
            CovJWcCallJSON.call("Assets", "transfer", ["id": .unsignedIntValue(1984), "target": CovJWcCallJSON.account(1), "amount": .unsignedIntValue(5)]),
            CovJWcCallJSON.call("Assets", "transfer", ["id": .unsignedIntValue(1984), "target": CovJWcCallJSON.account(1), "amount": .stringValue("7")]),
            CovJWcCallJSON.call("Balances", "transfer_keep_alive", ["dest": CovJWcCallJSON.account(2), "value": .unsignedIntValue(100)])
        ])]))
        XCTAssertEqual(CovJWcCallJSON.text.summaryLines(for: batch), [
            "1 × Balances.transfer_keep_alive → ADDR: 100 NAT",
            "2 × Assets.transfer (id: 1984) → ADDR: 12"
        ])
        let arguments = CovJWcCallJSON.text.text(forArgumentsOf: batch)
        XCTAssertTrue(arguments.contains("  3. Balances.transfer_keep_alive\n     dest: ADDR\n     value: 100 NAT"), arguments)
        XCTAssertTrue(arguments.contains("  1. Assets.transfer\n     amount: 5\n     id: 1984\n     target: ADDR"), arguments)
    }

    func testSummaryShowsOtherAssetIdsAndLeavesOutUnreadableAmounts() throws {
        let batch = RuntimeCall(moduleName: "Utility", callName: "batch_all", args: JSON.dictionaryValue(["calls": .arrayValue([
            CovJWcCallJSON.call("Tokens", "transfer", ["currency_id": .signedIntValue(-1), "amount": .stringValue("not-a-number")]),
            CovJWcCallJSON.call("XTokens", "transfer_multiasset", ["asset": .dictionaryValue(["parents": .unsignedIntValue(1)])])
        ])]))
        let lines = CovJWcCallJSON.text.summaryLines(for: batch)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.first, "1 × Tokens.transfer (currency_id: -1)")
        let multiasset = try XCTUnwrap(lines.last)
        XCTAssertTrue(multiasset.hasPrefix("1 × XTokens.transfer_multiasset (asset: "), multiasset)
        XCTAssertTrue(multiasset.contains("parents"), multiasset)
        XCTAssertFalse(multiasset.contains(":  "))
    }

    func testChainTextWithoutANativeAssetShowsRawAmounts() throws {
        let chain = CovJFixture.chain(id: "bare-chain", name: "Bare", assets: [], addressPrefix: 42)
        let text = WalletConnectSubstrateCallText.make(chain: chain, locale: CovJWcFixture.locale)
        let accountId = Data(repeating: 0x42, count: 32)
        let call = RuntimeCall(moduleName: "Balances", callName: "transfer_keep_alive", args: JSON.dictionaryValue([
            "dest": .arrayValue([.stringValue("Id"), .stringValue(accountId.toHex(includePrefix: true))]),
            "value": .unsignedIntValue(2500)
        ]))
        let address = try AddressFactory.address(for: accountId, chain: chain)
        XCTAssertEqual(text.text(forArgumentsOf: call), "dest: \(address)\nvalue: 2500")
        XCTAssertTrue(text.summaryLines(for: call).isEmpty)
        let hexOnly = WalletConnectSubstrateCallText(address: { _ in nil }, nativeAmount: { _ in nil })
        XCTAssertEqual(hexOnly.text(forArgumentsOf: call), "dest: \(accountId.toHex(includePrefix: true))\nvalue: 2500")
    }
}
