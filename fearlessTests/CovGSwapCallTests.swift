import BigInt
import Foundation
import SSFUtils
import XCTest
@testable import fearless

final class CovGSwapCallTests: XCTestCase {
    private let xor = "0x0200000000000000000000000000000000000000000000000000000000000000"
    private let val = "0x0200040000000000000000000000000000000000000000000000000000000000"

    func testSwapCallUsesLiquidityProxyPathAndFallsBackToDisabledFilter() throws {
        let factory = SubstrateCallFactoryDefault(runtimeService: CovGHistoryRuntime())
        let amount = [SwapVariant.desiredInput: SwapAmount(type: .desiredInput, desired: 10, slip: 9)]
        let call = try XCTUnwrap(
            factory.swap(dexId: "1", from: xor, to: val, amountCall: amount, type: [["XYKPool", nil]], filter: 2) as? RuntimeCall<SwapCall>
        )
        XCTAssertEqual(call.moduleName, "LiquidityProxy")
        XCTAssertEqual(call.callName, "swap")
        XCTAssertEqual(call.args.dexId, "1")
        XCTAssertEqual(call.args.inputAssetId.value, xor)
        XCTAssertEqual(call.args.outputAssetId.value, val)
        XCTAssertEqual(call.args.amount[.desiredInput]?.desired, 10)
        XCTAssertEqual(call.args.liquiditySourceType, [["XYKPool", nil]])
        XCTAssertEqual(call.args.filterMode.name, "AllowSelected")
        XCTAssertEqual(call.args.filterMode.value, 2)
        let fallback = try XCTUnwrap(
            factory.swap(dexId: "0", from: xor, to: val, amountCall: [:], type: [], filter: 99) as? RuntimeCall<SwapCall>
        )
        XCTAssertEqual(fallback.args.filterMode.name, "Disabled")
        XCTAssertEqual(fallback.args.filterMode.value, 99)
    }

    func testXorlessTransferKeepsArgumentsAndSnakeCaseKeys() throws {
        let factory = SubstrateCallFactoryDefault(runtimeService: CovGHistoryRuntime())
        let transfer = XorlessTransfer(
            dexId: "0", assetId: fearless.SoraAssetId(wrappedValue: val), receiver: Data(repeating: 1, count: 32), amount: 5,
            desiredXorAmount: 6, maxAmountIn: 7, selectedSourceTypes: [], filterMode: PolkaswapCallFilterModeType(wrappedName: "Disabled", wrappedValue: nil),
            additionalData: Data([9])
        )
        let call = try XCTUnwrap(factory.xorlessTransfer(transfer) as? RuntimeCall<XorlessTransfer>)
        XCTAssertEqual(call.moduleName, "LiquidityProxy")
        XCTAssertEqual(call.callName, "xorless_transfer")
        XCTAssertEqual(call.args.amount, 5)
        XCTAssertEqual(call.args.maxAmountIn, 7)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(call.args)) as? [String: Any])
        XCTAssertEqual(json["desired_xor_amount"] as? String, "6")
        XCTAssertEqual(json["max_amount_in"] as? String, "7")
        XCTAssertNotNil(json["filter_mode"])
        XCTAssertNotNil(json["additional_data"])
    }
}
