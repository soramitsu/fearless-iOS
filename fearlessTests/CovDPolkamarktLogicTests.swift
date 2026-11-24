import BigInt
import Foundation
import SSFModels
import XCTest

@testable import fearless

final class CovDPolkamarktDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testRuntimeEntryAcceptsNumericStringsNegativeAndDecimalValues() throws {
        let entry = try decode(
            PolkamarktRuntimeMarketEntry.self,
            #"{"marketId": 7, "conditionId": -3, "creator": "cnX", "closeBlock": 12.5, "status": "Open", "mechanism": "DPM", "question": "Q?", "category": "Crypto"}"#
        )
        XCTAssertEqual(entry.marketId, "7")
        XCTAssertEqual(entry.conditionId, "-3")
        XCTAssertEqual(entry.closeBlock, "12.5")
        XCTAssertEqual(entry.creator, "cnX")
        XCTAssertEqual(entry.status, "Open")
        XCTAssertEqual(entry.mechanism, "DPM")
        XCTAssertEqual(entry.question, "Q?")
        XCTAssertEqual(entry.category, "Crypto")

        let sparse = try decode(PolkamarktRuntimeMarketEntry.self, #"{"conditionId": null, "closeBlock": {"nested": 1}}"#)
        XCTAssertEqual(sparse.marketId, "")
        XCTAssertNil(sparse.conditionId)
        XCTAssertNil(sparse.closeBlock)
        XCTAssertNil(sparse.creator)
    }

    func testMarketStateFillsDefaultsForMissingValues() throws {
        let full = try decode(
            PolkamarktMarketState.self,
            #"""
            {
              "marketId": "9",
              "mechanism": "DPM",
              "virtualDepth": 10,
              "realYesShares": "11",
              "realNoShares": 12,
              "dpmCollateral": "13",
              "marginalYesPriceBps": 5000,
              "marginalNoPriceBps": 5000,
              "impliedYesProbabilityBps": 6400,
              "impliedNoProbabilityBps": "3600"
            }
            """#
        )
        XCTAssertEqual(full.marketId, "9")
        XCTAssertEqual(full.virtualDepth, "10")
        XCTAssertEqual(full.realNoShares, "12")
        XCTAssertEqual(full.impliedYesProbabilityBps, "6400")
        XCTAssertEqual(full.impliedNoProbabilityBps, "3600")

        let empty = try decode(PolkamarktMarketState.self, "{}")
        XCTAssertEqual(empty.marketId, "")
        XCTAssertEqual(empty.mechanism, "")
        XCTAssertEqual(empty.dpmCollateral, "0")
        XCTAssertEqual(empty.marginalYesPriceBps, "0")
    }

    func testQuotesDecodeAndDefault() throws {
        let buy = try decode(
            PolkamarktBuyQuote.self,
            #"{"marketId": 1, "outcome": "Yes", "collateralIn": "100", "feeAmount": 2, "pricingCollateral": "98", "sharesOut": 150}"#
        )
        XCTAssertEqual(buy, PolkamarktBuyQuote(
            marketId: "1", outcome: "Yes", collateralIn: "100", feeAmount: "2", pricingCollateral: "98", sharesOut: "150"
        ))
        let buyDefaults = try decode(PolkamarktBuyQuote.self, #"{"outcome": "No"}"#)
        XCTAssertEqual(buyDefaults.collateralIn, "0")
        XCTAssertEqual(buyDefaults.sharesOut, "0")
        XCTAssertThrowsError(try decode(PolkamarktBuyQuote.self, "{}"))

        let sell = try decode(
            PolkamarktSellQuote.self,
            #"{"marketId": "1", "outcome": "No", "sharesIn": 50, "grossCollateralOut": "40", "feeAmount": "1", "collateralOut": 39}"#
        )
        XCTAssertEqual(sell, PolkamarktSellQuote(
            marketId: "1", outcome: "No", sharesIn: "50", grossCollateralOut: "40", feeAmount: "1", collateralOut: "39"
        ))
        let sellDefaults = try decode(PolkamarktSellQuote.self, #"{"outcome": "Yes"}"#)
        XCTAssertEqual(sellDefaults.grossCollateralOut, "0")
        XCTAssertEqual(sellDefaults.marketId, "")
    }

    func testClaimableUsesClaimablePayoutBeforeTraderPayout() throws {
        let withClaimable = try decode(
            PolkamarktClaimable.self,
            #"""
            {
              "marketId": 4,
              "account": "cnA",
              "status": "Resolved",
              "resolutionOutcome": "Yes",
              "yesShares": 3,
              "noShares": "0",
              "netCollateralPaid": "5",
              "traderPayout": "6",
              "claimablePayout": 7,
              "creatorFees": "8",
              "isCreator": true
            }
            """#
        )
        XCTAssertEqual(withClaimable.effectiveTraderPayout, "7")
        XCTAssertTrue(withClaimable.isCreator)
        XCTAssertEqual(withClaimable.resolutionOutcome, "Yes")
        XCTAssertEqual(withClaimable.creatorFees, "8")

        let fallback = try decode(PolkamarktClaimable.self, #"{"traderPayout": "6"}"#)
        XCTAssertEqual(fallback.effectiveTraderPayout, "6")
        XCTAssertFalse(fallback.isCreator)
        XCTAssertEqual(fallback.account, "")
        XCTAssertEqual(fallback.status, "")
        XCTAssertEqual(fallback.yesShares, "0")
    }

    func testHistoryPositionAndTradeDecode() throws {
        let point = try decode(
            PolkamarktHistoryPoint.self,
            #"""
            {
              "id": "h1",
              "marketId": 2,
              "timestamp": "1700",
              "blockHeight": 99,
              "probability": "0.4",
              "priceYes": "0.4",
              "priceNo": "0.6",
              "liquidityUSD": 10,
              "volumeUSD": "20",
              "status": "Open"
            }
            """#
        )
        XCTAssertEqual(point.blockHeight, "99")
        XCTAssertEqual(point.liquidityUSD, "10")
        XCTAssertEqual(point.status, "Open")
        let sparsePoint = try decode(PolkamarktHistoryPoint.self, #"{"id": "h2"}"#)
        XCTAssertEqual(sparsePoint.probability, "0")
        XCTAssertNil(sparsePoint.priceYes)

        let position = try decode(
            PolkamarktPosition.self,
            #"{"id": "p1", "marketId": 3, "outcome": "Yes", "shares": "5", "netCollateralPaid": 4, "status": "Open"}"#
        )
        XCTAssertEqual(position.marketId, "3")
        XCTAssertEqual(position.netCollateralPaid, "4")
        let sparsePosition = try decode(PolkamarktPosition.self, #"{"id": "p2"}"#)
        XCTAssertEqual(sparsePosition.outcome, "")
        XCTAssertEqual(sparsePosition.shares, "0")

        let trade = try decode(
            PolkamarktTrade.self,
            #"{"id": "t1", "marketId": 3, "side": "buy", "outcome": "No", "collateral": "10", "sharesOut": 9, "fee": "1", "blockNumber": 77, "extrinsicHash": "0xab"}"#
        )
        XCTAssertEqual(trade.blockNumber, "77")
        XCTAssertEqual(trade.extrinsicHash, "0xab")
        let sparseTrade = try decode(PolkamarktTrade.self, #"{"id": "t2"}"#)
        XCTAssertEqual(sparseTrade.side, "")
        XCTAssertEqual(sparseTrade.blockNumber, "0")
        XCTAssertNil(sparseTrade.extrinsicHash)
    }

    func testMarketNodeBuildsMarketOnlyWithTitle() throws {
        let node = try decode(PolkamarktMarketNode.self, #"{"id": "n1", "title": "Rain?", "priceYes": "0.3"}"#)
        let market = try XCTUnwrap(node.market)
        XCTAssertEqual(market.marketId, "n1")
        XCTAssertEqual(market.category, "Other")
        XCTAssertEqual(market.liquidityUSD, "0")
        XCTAssertEqual(market.volumeUSD, "0")
        XCTAssertEqual(market.yesProbability, "0.3")
        XCTAssertTrue(market.marketDescription.contains("oracle"))

        let explicit = try decode(
            PolkamarktMarketNode.self,
            #"""
            {
              "id": "n2",
              "marketId": 5,
              "conditionId": 6,
              "creator": "cnC",
              "title": "Sun?",
              "description": "D",
              "category": "Weather",
              "closeBlock": 100,
              "liquidityUSD": "7",
              "volumeUSD": 8,
              "probability": "0.9",
              "priceYes": "0.1",
              "status": "Open",
              "mechanism": "DPM"
            }
            """#
        )
        let explicitMarket = try XCTUnwrap(explicit.market)
        XCTAssertEqual(explicitMarket.marketId, "5")
        XCTAssertEqual(explicitMarket.yesProbability, "0.9")
        XCTAssertEqual(explicitMarket.marketDescription, "D")
        XCTAssertEqual(explicitMarket.closeBlock, "100")

        XCTAssertNil(try decode(PolkamarktMarketNode.self, #"{"id": "n3", "title": ""}"#).market)
        XCTAssertNil(try decode(PolkamarktMarketNode.self, #"{"id": "n4"}"#).market)
    }
}

final class CovDPolkamarktCatalogTests: XCTestCase {
    static func market(
        id: String,
        liquidity: String = "0",
        closeBlock: String? = nil,
        status: String? = nil,
        title: String? = nil
    ) -> PolkamarktMarket {
        PolkamarktMarket(
            marketId: id,
            conditionId: nil,
            creator: nil,
            title: title ?? "Market \(id)",
            marketDescription: "desc",
            category: "Cat",
            closeBlock: closeBlock,
            liquidityUSD: liquidity,
            volumeUSD: "0",
            yesProbability: nil,
            indexedStatus: status,
            mechanism: nil,
            runtimeState: nil
        )
    }

    func testOutcomeAndDisplayStatus() {
        XCTAssertEqual(PolkamarktOutcome(caseInsensitive: "YES"), .yes)
        XCTAssertEqual(PolkamarktOutcome(caseInsensitive: "no"), .no)
        XCTAssertNil(PolkamarktOutcome(caseInsensitive: "maybe"))
        XCTAssertEqual(PolkamarktOutcome.allCases.map(\.rawValue), ["Yes", "No"])

        XCTAssertEqual(Self.market(id: "1", status: "Cancelled").displayStatus(currentBlock: "1"), .cancelled)
        XCTAssertEqual(Self.market(id: "1", status: "Resolved").displayStatus(currentBlock: "1"), .resolved)
        XCTAssertEqual(Self.market(id: "1", status: "Finalized").displayStatus(currentBlock: "1"), .resolved)
        XCTAssertEqual(Self.market(id: "1", closeBlock: "10").displayStatus(currentBlock: "10"), .closed)
        XCTAssertEqual(Self.market(id: "1", closeBlock: "10").displayStatus(currentBlock: "9"), .open)
        XCTAssertEqual(Self.market(id: "1", status: "closed").displayStatus(currentBlock: "x"), .closed)
        XCTAssertEqual(Self.market(id: "1").displayStatus(currentBlock: "x"), .open)
        XCTAssertTrue(PolkamarktDisplayStatus.open.isOpen)
        XCTAssertFalse(PolkamarktDisplayStatus.resolved.isOpen)
    }

    func testMergeEnrichesIndexedMarketsAndAddsRuntimeOnlyMarkets() throws {
        let indexed = [
            Self.market(id: "2", liquidity: "50"),
            Self.market(id: "1", liquidity: "50", closeBlock: "5")
        ]
        let runtime = [
            PolkamarktRuntimeMarketEntry(
                marketId: "2", conditionId: "c2", creator: "cnCreator", closeBlock: "500",
                status: "Open", mechanism: "DPM", question: nil, category: nil
            ),
            PolkamarktRuntimeMarketEntry(
                marketId: "3", conditionId: "c3", creator: nil, closeBlock: "900",
                status: "Open", mechanism: nil, question: nil, category: nil
            )
        ]
        let state = try JSONDecoder().decode(
            PolkamarktMarketState.self,
            from: Data(#"{"marketId": "3", "mechanism": "", "dpmCollateral": "75", "impliedYesProbabilityBps": "2500"}"#.utf8)
        )

        let merged = PolkamarktCatalog.merge(
            indexed: indexed,
            runtime: runtime,
            states: ["3": state],
            currentBlock: "10"
        )

        XCTAssertEqual(merged.map(\.marketId), ["3", "2", "1"])
        let runtimeOnly = merged[0]
        XCTAssertEqual(runtimeOnly.title, "SORA market #3")
        XCTAssertEqual(runtimeOnly.category, "Other")
        XCTAssertEqual(runtimeOnly.liquidityUSD, "75")
        XCTAssertEqual(runtimeOnly.yesProbability, "0.25")
        XCTAssertEqual(runtimeOnly.runtimeState, state)
        let enriched = merged[1]
        XCTAssertEqual(enriched.conditionId, "c2")
        XCTAssertEqual(enriched.creator, "cnCreator")
        XCTAssertEqual(enriched.closeBlock, "500")
        XCTAssertEqual(enriched.mechanism, "DPM")
        XCTAssertNil(enriched.runtimeState)
        XCTAssertEqual(merged[2].displayStatus(currentBlock: "10"), .closed)

        XCTAssertEqual(PolkamarktCatalog.activeMarkets(merged, currentBlock: "10").map(\.marketId), ["3", "2"])
    }

    func testMergeOrdersEqualLiquidityByNumericIdAndUsesRuntimeQuestion() {
        let runtime = [
            PolkamarktRuntimeMarketEntry(
                marketId: "10", conditionId: nil, creator: nil, closeBlock: nil,
                status: nil, mechanism: nil, question: "Ten?", category: "Sport"
            ),
            PolkamarktRuntimeMarketEntry(
                marketId: "9", conditionId: nil, creator: nil, closeBlock: nil,
                status: nil, mechanism: nil, question: "Nine?", category: nil
            )
        ]
        let merged = PolkamarktCatalog.merge(indexed: [], runtime: runtime, currentBlock: "1")
        XCTAssertEqual(merged.map(\.marketId), ["9", "10"])
        XCTAssertEqual(merged[1].title, "Ten?")
        XCTAssertEqual(merged[1].category, "Sport")
        XCTAssertNil(merged[1].yesProbability)
    }

    func testRPCRequestBuilderValidatesMethodsAndIntegers() throws {
        XCTAssertEqual(
            try PolkamarktRPCRequestBuilder.parametersJSON([.unsignedInteger("007"), .text("Yes \"quoted\"")]),
            #"[7,"Yes \"quoted\""]"#
        )
        XCTAssertEqual(try PolkamarktRPCRequestBuilder.parametersJSON([]), "[]")
        XCTAssertThrowsError(try PolkamarktRPCRequestBuilder.parametersJSON([.unsignedInteger("")]))
        XCTAssertThrowsError(try PolkamarktRPCRequestBuilder.parametersJSON([.unsignedInteger("12a")]))
        let overflow = ((BigUInt(1) << 128)).description
        XCTAssertThrowsError(try PolkamarktRPCRequestBuilder.parametersJSON([.unsignedInteger(overflow)])) { error in
            guard case PolkamarktRPCRequestBuilder.Error.unsignedIntegerOverflow = error else {
                return XCTFail("unexpected \(error)")
            }
        }
        let maximum = ((BigUInt(1) << 128) - 1).description
        XCTAssertEqual(try PolkamarktRPCRequestBuilder.parametersJSON([.unsignedInteger(maximum)]), "[\(maximum)]")

        let data = try PolkamarktRPCRequestBuilder.requestData(method: "chain_getHeader", parameters: [], identifier: 4)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"jsonrpc":"2.0","id":4,"method":"chain_getHeader","params":[]}"#)
        XCTAssertThrowsError(try PolkamarktRPCRequestBuilder.requestData(method: "", parameters: []))
        XCTAssertThrowsError(try PolkamarktRPCRequestBuilder.requestData(method: "bad-method", parameters: [])) { error in
            guard case PolkamarktRPCRequestBuilder.Error.invalidMethod = error else {
                return XCTFail("unexpected \(error)")
            }
        }
        XCTAssertEqual(PolkamarktRPCParameter.text("a"), .text("a"))
        XCTAssertNotEqual(PolkamarktRPCParameter.text("1"), .unsignedInteger("1"))
    }

    func testEndpointResolverMapsSocketSchemesAndRejectsOthers() {
        XCTAssertEqual(
            PolkamarktEndpointResolver.rpcHTTPURL(for: CovDFixtures.soraChain(nodeURL: "wss://sora.invalid/public-ws"))?.absoluteString,
            "https://sora.invalid/public"
        )
        XCTAssertEqual(
            PolkamarktEndpointResolver.rpcHTTPURL(for: CovDFixtures.soraChain(nodeURL: "ws://sora.invalid/rpc"))?.absoluteString,
            "http://sora.invalid/rpc"
        )
        XCTAssertEqual(
            PolkamarktEndpointResolver.rpcHTTPURL(for: CovDFixtures.soraChain(nodeURL: "https://sora.invalid"))?.absoluteString,
            "https://sora.invalid"
        )
        XCTAssertNil(PolkamarktEndpointResolver.rpcHTTPURL(for: CovDFixtures.soraChain(nodeURL: "ftp://sora.invalid")))
        XCTAssertNil(PolkamarktEndpointResolver.rpcHTTPURL(for: CovDFixtures.soraChain(nodeURL: nil)))
    }

    func testErrorDescriptionsAreUserFacing() {
        XCTAssertEqual(PolkamarktServiceError.unavailable("why").errorDescription, "why")
        XCTAssertEqual(PolkamarktServiceError.rpc("boom").errorDescription, "boom")
        XCTAssertTrue(PolkamarktServiceError.invalidResponse.errorDescription?.contains("invalid response") == true)
        XCTAssertTrue(PolkamarktServiceError.watchOnly.errorDescription?.contains("watch-only") == true)
        XCTAssertTrue(PolkamarktServiceError.actionsPaused.errorDescription?.contains("safety switch") == true)

        let all: [PolkamarktSubmissionError] = [
            .runtimeUnavailable, .signerUnavailable, .selectedWalletChanged, .marketUnavailable, .marketClosed,
            .quoteMismatch, .collateralFeeMismatch, .insufficientShares, .claimUnavailable, .balanceUnavailable,
            .insufficientCollateral, .insufficientFee
        ]
        let descriptions = all.compactMap(\.errorDescription)
        XCTAssertEqual(descriptions.count, all.count)
        XCTAssertEqual(Set(descriptions).count, all.count)
        XCTAssertEqual(PolkamarktSubmissionError.marketClosed.errorDescription, "The market is not open at the current SORA block.")
    }

    func testDeepLinkHandlerRejectsNonCanonicalLinksAndNotifiesOnce() throws {
        let suite = "CovDPolkamarkt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = CovDEventCenterSpy()
        let handler = PolkamarktDeepLinkHandler(eventCenter: center, userDefaults: defaults)

        for link in [
            "https://defi/polkamarkt/7", "fearless://wallet/polkamarkt/7", "fearless://defi/polkamarkt",
            "fearless://defi/other/7", "fearless://defi/polkamarkt/4294967296", "fearless://defi/polkamarkt/7/8"
        ] {
            XCTAssertFalse(handler.handle(url: try XCTUnwrap(URL(string: link))), link)
        }
        XCTAssertTrue(center.events.isEmpty)
        XCTAssertNil(PolkamarktDeepLinkHandler.consumePending(userDefaults: defaults))

        XCTAssertTrue(handler.handle(url: try XCTUnwrap(URL(string: "FEARLESS://DEFI/Polkamarkt/0042"))))
        let event = try XCTUnwrap(center.events.first as? PolkamarktDeepLinkRequested)
        XCTAssertEqual(event.marketId, "42")
        let visitor = CovDPolkamarktVisitor()
        event.accept(visitor: visitor)
        XCTAssertEqual(visitor.marketIds, ["42"])
        XCTAssertEqual(PolkamarktDeepLinkHandler.consumePending(userDefaults: defaults), "42")
    }
}

final class CovDEventCenterSpy: EventCenterProtocol, @unchecked Sendable {
    private(set) var events: [EventProtocol] = []
    private(set) var observers: [EventVisitorProtocol] = []

    func notify(with event: EventProtocol) { events.append(event) }
    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) { observers.append(observer) }
    func remove(observer _: EventVisitorProtocol) {}
}

final class CovDPolkamarktVisitor: EventVisitorProtocol {
    private(set) var marketIds: [String] = []

    func processPolkamarktDeepLinkRequested(event: PolkamarktDeepLinkRequested) {
        marketIds.append(event.marketId)
    }
}
