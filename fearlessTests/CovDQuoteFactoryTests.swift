import Foundation
import SSFModels
import XCTest

@testable import fearless

final class CovDQuoteFactoryTests: XCTestCase {
    private func params(amount: String, variant: SwapVariant) -> PolkaswapQuoteParams {
        PolkaswapQuoteParams(
            fromAssetId: CovDFixtures.xorAssetId,
            toAssetId: CovDSwapFixtures.tokenId,
            amount: amount,
            swapVariant: variant,
            liquiditySources: [],
            filterMode: .disabled
        )
    }

    func testAmountsPickTheBestQuoteForEachDirectionAndRejectUnreadableInput() throws {
        let chain = CovDSwapFixtures.chain(chainId: "covd-quote-\(UUID().uuidString)")
        let xor = try XCTUnwrap(chain.chainAssets.first { $0.asset.symbol == "XOR" })
        let token = try XCTUnwrap(chain.chainAssets.first { $0.asset.symbol == "TKN" })
        let factory = PolkaswapAdjustmentViewModelFactory(
            wallet: CovDFixtures.wallet(), xorChainAsset: xor, assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let quotes = [
            SwapValues(dexId: 0, amount: "3000000000000000000", rewards: []),
            SwapValues(dexId: 1, amount: "5000000000000000000", rewards: []),
            SwapValues(dexId: 1, amount: "not-a-number", rewards: [])
        ]

        let sell = try XCTUnwrap(factory.createAmounts(
            fromAsset: xor.asset, toAsset: token.asset, params: params(amount: "2000000000000000000", variant: .desiredInput),
            quote: quotes, swapVariant: .desiredInput
        ))
        XCTAssertEqual(sell.bestQuote.dexId, 1)
        XCTAssertEqual(sell.fromAmount, 2)
        XCTAssertEqual(sell.toAmount, 5)

        let buy = try XCTUnwrap(factory.createAmounts(
            fromAsset: xor.asset, toAsset: token.asset, params: params(amount: "2000000000000000000", variant: .desiredOutput),
            quote: quotes, swapVariant: .desiredOutput
        ))
        XCTAssertEqual(buy.bestQuote.dexId, 0)
        XCTAssertEqual(buy.toAmount, 3)

        XCTAssertNil(factory.createAmounts(
            fromAsset: xor.asset, toAsset: token.asset, params: params(amount: "1", variant: .desiredOutput),
            quote: [SwapValues(dexId: 0, amount: "bad", rewards: [])], swapVariant: .desiredOutput
        ))
        XCTAssertNil(factory.createAmounts(
            fromAsset: nil, toAsset: token.asset, params: params(amount: "1", variant: .desiredInput),
            quote: quotes, swapVariant: .desiredInput
        ))
        XCTAssertNil(factory.createAmounts(
            fromAsset: xor.asset, toAsset: token.asset, params: params(amount: "1.5", variant: .desiredInput),
            quote: quotes, swapVariant: .desiredInput
        ))

        let details = try XCTUnwrap(factory.createDetailsViewModel(
            with: buy, swapToChainAsset: token, swapFromChainAsset: xor, swapVariant: .desiredOutput,
            availableDexIds: [PolkaswapDex(name: "xor", code: 0, assetId: CovDFixtures.xorAssetId)],
            slippadgeTolerance: 1, locale: Locale(identifier: "en_US")
        ))
        XCTAssertEqual(details.route, "XOR->TKN")
        XCTAssertEqual(details.fromPerToTitle, "XOR / TKN")
        XCTAssertEqual(details.toPerFromTitle, "TKN / XOR")
        XCTAssertEqual(details.minMaxReceiveValue, Decimal(3) * Decimal(1.01))
        XCTAssertNil(factory.createDetailsViewModel(
            with: .mockQuoteAmount, swapToChainAsset: token, swapFromChainAsset: xor, swapVariant: .desiredInput,
            availableDexIds: [], slippadgeTolerance: 1, locale: Locale(identifier: "en_US")
        ))
    }
}
