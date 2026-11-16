import BigInt
import Foundation
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovGSubstrateCallsTests: XCTestCase {
    private let account = Data(repeating: 1, count: 32)

    func testTransferCallUsesPalletSpecificKeysForEveryCurrencyShape() throws {
        let dest = MultiAddress.accoundId(account)
        let cases: [(SSFModels.CurrencyId?, Set<String>, String)] = [
            (nil, ["dest", "value"], "value"),
            (.equilibrium(id: "7"), ["asset", "to", "value"], "value"),
            (.soraAsset(id: "0x0200"), ["asset_id", "to", "amount"], "amount"),
            (.assets(id: "8"), ["id", "target", "amount"], "amount"),
            (.assetId(id: "9"), ["dest", "currency_id", "amount"], "amount"),
            (.ormlAsset(symbol: SSFModels.TokenSymbol(symbol: "ksm")), ["dest", "currency_id", "amount"], "amount"),
            (.xcm(id: "10"), ["dest", "currency_id", "amount"], "amount"),
        ]
        for (currency, keys, amountKey) in cases {
            let object = try encode(TransferCall(dest: dest, value: 53, currencyId: currency))
            XCTAssertEqual(Set(object.keys), keys, "\(String(describing: currency))")
            XCTAssertEqual(object[amountKey] as? String, "53")
        }
        let encoded = try JSONEncoder().encode(TransferCall(dest: dest, value: 53, currencyId: nil))
        let decoded = try JSONDecoder().decode(TransferCall.self, from: encoded)
        XCTAssertEqual(decoded.dest, dest)
        XCTAssertEqual(decoded.value, 53)
        XCTAssertNil(decoded.currencyId)
        let symbol = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fearless.TokenSymbol(symbol: "dot"))) as? [Any]
        XCTAssertEqual(symbol?.first as? String, "DOT")
        XCTAssertTrue(symbol?.last is NSNull)
    }

    func testBondCallEncodesOptionalControllerAndEveryRewardDestination() throws {
        let withController = try encode(BondCall(controller: .accoundId(account), value: 7, payee: .staked))
        XCTAssertEqual(Set(withController.keys), ["controller", "value", "payee"])
        XCTAssertEqual(withController["value"] as? String, "7")
        let withoutController = try encode(BondCall(controller: nil, value: 8, payee: .stash))
        XCTAssertEqual(Set(withoutController.keys), ["value", "payee"])
        let destinations: [RewardDestinationArg] = [.staked, .stash, .controller]
        for destination in destinations {
            let data = try JSONEncoder().encode(destination)
            XCTAssertEqual(try JSONDecoder().decode(RewardDestinationArg.self, from: data), destination)
        }
        let address = try JSONSerialization.jsonObject(with: JSONEncoder().encode(RewardDestinationArg.address("owner"))) as? [Any]
        XCTAssertEqual(address?.first as? String, RewardDestinationArg.accountField)
        XCTAssertEqual(address?.last as? String, "owner")
        let hex = Data(#"["Account","0x0101"]"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(RewardDestinationArg.self, from: hex), .account(Data([1, 1])))
        XCTAssertThrowsError(try JSONDecoder().decode(RewardDestinationArg.self, from: Data(#"["Unknown",null]"#.utf8)))
    }

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
}
