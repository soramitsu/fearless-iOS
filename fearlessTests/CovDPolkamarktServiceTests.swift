import BigInt
import Foundation
import SoraKeystore
import SSFModels
import XCTest

@testable import fearless

final class CovDPolkamarktClientTests: XCTestCase {
    private let endpoint = URL(string: "https://rpc.invalid")!

    func testRPCClientReadsEveryMethodThroughTheTransport() async throws {
        let transport = CovDRoutingTransport()
        transport.setRPC("rpc_methods", result: ["methods": ["polkamarkt_quoteBuy", "chain_getHeader"]])
        transport.setRPC("chain_getHeader", result: ["number": "0x1f"])
        transport.setRPC("polkamarkt_marketState", result: ["marketId": 3, "mechanism": "DPM"])
        transport.setRPC("polkamarkt_quoteBuy", result: [
            "marketId": "3", "outcome": "Yes", "collateralIn": "100", "feeAmount": "1", "pricingCollateral": "99", "sharesOut": "150"
        ])
        transport.setRPC("polkamarkt_quoteSell", result: [
            "marketId": "3", "outcome": "No", "sharesIn": "10", "grossCollateralOut": "9", "feeAmount": "1", "collateralOut": "8"
        ])
        transport.setRPC("polkamarkt_claimable", result: ["marketId": "3", "account": "cnA", "traderPayout": "5"])
        let client = PolkamarktRPCClient(endpoint: endpoint, transport: transport)

        let methods = try await client.methods()
        XCTAssertEqual(methods, ["polkamarkt_quoteBuy", "chain_getHeader"])
        let block = try await client.currentBlock()
        XCTAssertEqual(block, "31")
        let state = try await client.marketState(marketId: "3")
        XCTAssertEqual(state.marketId, "3")
        let buy = try await client.quoteBuy(marketId: "3", outcome: .yes, collateralIn: "100")
        XCTAssertEqual(buy.sharesOut, "150")
        let sell = try await client.quoteSell(marketId: "3", outcome: .no, sharesIn: "10")
        XCTAssertEqual(sell.collateralOut, "8")
        let claim = try await client.claimable(account: "cnA", marketId: "3")
        XCTAssertEqual(claim.effectiveTraderPayout, "5")
        XCTAssertEqual(client.endpoint, endpoint)
        XCTAssertEqual(transport.recordedMethods(), [
            "rpc_methods", "chain_getHeader", "polkamarkt_marketState", "polkamarkt_quoteBuy",
            "polkamarkt_quoteSell", "polkamarkt_claimable"
        ])
    }

    func testRPCClientSurfacesErrorsAndRejectsMissingResults() async throws {
        let transport = CovDRoutingTransport()
        transport.setRPCError("polkamarkt_marketState", message: "Unknown market")
        transport.setRPC("chain_getHeader", result: ["number": "zz"])
        let client = PolkamarktRPCClient(endpoint: endpoint, transport: transport)

        do {
            _ = try await client.marketState(marketId: "1")
            XCTFail("expected rpc error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Unknown market")
        }
        do {
            _ = try await client.currentBlock()
            XCTFail("expected invalid response")
        } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.invalidResponse.localizedDescription)
        }
        do {
            _ = try await client.quoteBuy(marketId: "x", outcome: .yes, collateralIn: "1")
            XCTFail("expected parameter validation")
        } catch {
            XCTAssertTrue(error is PolkamarktRPCRequestBuilder.Error)
        }
    }

    func testIndexerClientSortsHistoryAndTradesAndReadsPositions() async throws {
        let transport = CovDRoutingTransport()
        transport.setGraphQL("marketSnapshots", response: ["data": ["marketSnapshots": ["edges": [
            ["node": ["id": "b", "blockHeight": "20", "probability": "0.6"]],
            ["node": NSNull()],
            ["node": ["id": "a", "blockHeight": 10, "probability": "0.4"]]
        ]]]])
        transport.setGraphQL("accountPositions", response: ["data": ["accountPositions": ["edges": [
            ["node": ["id": "p1", "marketId": "3", "outcome": "Yes", "shares": "5", "netCollateralPaid": "2", "status": "Open"]]
        ]]]])
        transport.setGraphQL("trades(first", response: ["data": ["trades": ["edges": [
            ["node": ["id": "t1", "blockNumber": "5"]],
            ["node": ["id": "t2", "blockNumber": "9"]]
        ]]]])
        transport.setGraphQL("PolkamarktLatestMarkets", response: ["data": ["markets": ["edges": [
            ["node": ["id": "m1", "title": "One"]],
            ["node": ["id": "m2"]]
        ]]]])
        let client = PolkamarktIndexerClient(endpoint: endpoint, transport: transport)

        let history = try await client.history(marketId: "3")
        XCTAssertEqual(history.map(\.id), ["a", "b"])
        let none = try await client.history(marketId: "not-a-number")
        XCTAssertTrue(none.isEmpty)
        let positions = try await client.positions(account: "cnA")
        XCTAssertEqual(positions.map(\.id), ["p1"])
        let trades = try await client.trades(account: "cnA")
        XCTAssertEqual(trades.map(\.id), ["t2", "t1"])
        let markets = try await client.markets()
        XCTAssertEqual(markets.map(\.marketId), ["m1"])
    }

    func testIndexerClientMapsGraphQLErrorsAndMissingData() async {
        let transport = CovDRoutingTransport()
        transport.setGraphQL("accountPositions", response: ["errors": [["message": "schema drift"]]])
        transport.setGraphQL("trades(first", response: ["data": NSNull()])
        let client = PolkamarktIndexerClient(endpoint: endpoint, transport: transport)

        do {
            _ = try await client.positions(account: "cnA")
            XCTFail("expected graphql error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "schema drift")
        }
        do {
            _ = try await client.trades(account: "cnA")
            XCTFail("expected invalid response")
        } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.invalidResponse.localizedDescription)
        }
        do {
            _ = try await client.markets()
            XCTFail("both market queries fail without responses")
        } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.invalidResponse.localizedDescription)
        }
    }
}

final class CovDPolkamarktMutationTests: XCTestCase {
    static let complete = PolkamarktRuntimeCapabilities(
        palletAvailable: true,
        storage: ["Polkamarkt_Markets", "conditions"],
        rpc: ["polkamarkt_marketState", "polkamarkt_quoteBuy", "polkamarkt_quoteSell", "polkamarkt_claimable"],
        calls: ["buy", "sell", "claim_market", "claim_creator_fees"],
        claimablePayoutFieldAvailable: true
    )

    func testCapabilitiesNormalizeNamesAndExplainMissingRoutes() {
        let caps = Self.complete
        XCTAssertTrue(caps.hasStorage("Markets"))
        XCTAssertTrue(caps.hasRPC("quote_buy"))
        XCTAssertTrue(caps.hasCall("claimMarket"))
        XCTAssertTrue(caps.canBrowseRuntime)
        XCTAssertTrue(caps.canTrade)
        XCTAssertTrue(caps.canReadClaims)
        XCTAssertTrue(caps.canClaimTrader)
        XCTAssertTrue(caps.canClaimCreator)
        XCTAssertNil(caps.tradingUnavailableReason)
        XCTAssertEqual(caps.resolvedCallName("claimCreatorFees"), "claim_creator_fees")
        XCTAssertNil(caps.resolvedCallName("redeem"))

        let noPallet = PolkamarktRuntimeCapabilities(
            palletAvailable: false, storage: [], rpc: [], calls: [], claimablePayoutFieldAvailable: false
        )
        XCTAssertFalse(noPallet.canBrowseRuntime)
        XCTAssertFalse(noPallet.canClaimTrader)
        XCTAssertEqual(noPallet.tradingUnavailableReason, "The connected SORA runtime does not expose the Polkamarkt pallet.")

        let noState = PolkamarktRuntimeCapabilities(
            palletAvailable: true, storage: [], rpc: ["quoteBuy"], calls: ["buy"], claimablePayoutFieldAvailable: true
        )
        XCTAssertEqual(noState.tradingUnavailableReason, "Market state RPC is unavailable; browse and history remain available.")

        let noQuote = PolkamarktRuntimeCapabilities(
            palletAvailable: true, storage: [], rpc: ["marketState"], calls: [], claimablePayoutFieldAvailable: true
        )
        XCTAssertEqual(noQuote.tradingUnavailableReason, "Required Polkamarkt quote or trade capabilities are unavailable on this runtime.")
    }

    func testMutationExposesAuthorizationFieldsAndCollateral() {
        let buy = PolkamarktMutation.buy(marketId: "1", outcome: .yes, collateralIn: "100", minSharesOut: "99")
        let sell = PolkamarktMutation.sell(marketId: "2", outcome: .no, sharesIn: "5", minCollateralOut: "4")
        XCTAssertEqual(buy.authorizationFields, ["buy", "1", "Yes", "100", "99"])
        XCTAssertEqual(sell.authorizationFields, ["sell", "2", "No", "5", "4"])
        XCTAssertEqual(PolkamarktMutation.claimTrader(marketId: "3").authorizationFields, ["claimTrader", "3"])
        XCTAssertEqual(PolkamarktMutation.claimCreator(marketId: "4").authorizationFields, ["claimCreator", "4"])
        XCTAssertEqual(buy.requiredCollateral, BigUInt(100))
        XCTAssertNil(sell.requiredCollateral)
        XCTAssertEqual([buy, sell, .claimTrader(marketId: "3"), .claimCreator(marketId: "4")].map(\.marketId), ["1", "2", "3", "4"])
    }

    func testQuoteValidatorAcceptsExactQuotesAndRejectsDrift() throws {
        let buyQuote = PolkamarktBuyQuote(
            marketId: "1", outcome: "yes", collateralIn: "100", feeAmount: "2", pricingCollateral: "98", sharesOut: "200"
        )
        XCTAssertNoThrow(try PolkamarktMutationQuoteValidator.validateBuy(
            marketId: "1", outcome: .yes, collateralIn: "100", minSharesOut: "198", quote: buyQuote
        ))
        XCTAssertThrowsError(try PolkamarktMutationQuoteValidator.validateBuy(
            marketId: "1", outcome: .yes, collateralIn: "100", minSharesOut: "100", quote: buyQuote
        )) { XCTAssertEqual($0 as? PolkamarktSubmissionError, .quoteMismatch) }
        XCTAssertThrowsError(try PolkamarktMutationQuoteValidator.validateBuy(
            marketId: "1", outcome: .no, collateralIn: "100", minSharesOut: "198", quote: buyQuote
        )) { XCTAssertEqual($0 as? PolkamarktSubmissionError, .quoteMismatch) }
        let feeDrift = PolkamarktBuyQuote(
            marketId: "1", outcome: "Yes", collateralIn: "100", feeAmount: "5", pricingCollateral: "98", sharesOut: "200"
        )
        XCTAssertThrowsError(try PolkamarktMutationQuoteValidator.validateBuy(
            marketId: "1", outcome: .yes, collateralIn: "100", minSharesOut: "198", quote: feeDrift
        )) { XCTAssertEqual($0 as? PolkamarktSubmissionError, .collateralFeeMismatch) }

        let sellQuote = PolkamarktSellQuote(
            marketId: "1", outcome: "No", sharesIn: "50", grossCollateralOut: "41", feeAmount: "1", collateralOut: "40"
        )
        XCTAssertNoThrow(try PolkamarktMutationQuoteValidator.validateSell(
            marketId: "1", outcome: .no, sharesIn: "50", minCollateralOut: "40", quote: sellQuote
        ))
        XCTAssertThrowsError(try PolkamarktMutationQuoteValidator.validateSell(
            marketId: "1", outcome: .no, sharesIn: "51", minCollateralOut: "40", quote: sellQuote
        )) { XCTAssertEqual($0 as? PolkamarktSubmissionError, .quoteMismatch) }
        let sellDrift = PolkamarktSellQuote(
            marketId: "1", outcome: "No", sharesIn: "50", grossCollateralOut: "45", feeAmount: "1", collateralOut: "40"
        )
        XCTAssertThrowsError(try PolkamarktMutationQuoteValidator.validateSell(
            marketId: "1", outcome: .no, sharesIn: "50", minCollateralOut: "40", quote: sellDrift
        )) { XCTAssertEqual($0 as? PolkamarktSubmissionError, .collateralFeeMismatch) }
    }

    func testCallBuilderResolvesRuntimeNamesAndRefusesMissingCapabilities() throws {
        let builder = PolkamarktMutationCallBuilder()
        let mutations: [(PolkamarktMutation, String)] = [
            (.buy(marketId: "1", outcome: .yes, collateralIn: "10", minSharesOut: "9"), "buy"),
            (.sell(marketId: "1", outcome: .no, sharesIn: "10", minCollateralOut: "9"), "sell"),
            (.claimTrader(marketId: "1"), "claim_market"),
            (.claimCreator(marketId: "1"), "claim_creator_fees")
        ]
        for (mutation, expectedCall) in mutations {
            let closure = try builder.builder(for: mutation, capabilities: Self.complete)
            let spy = CovDExtrinsicBuilderSpy()
            _ = try closure(spy)
            XCTAssertEqual(spy.calls.first?.module, "Polkamarkt")
            XCTAssertEqual(spy.calls.first?.call, expectedCall)
            XCTAssertEqual(spy.argsObject(at: 0)?["market_id"] as? String, "1")
        }

        let empty = PolkamarktRuntimeCapabilities(
            palletAvailable: false, storage: [], rpc: [], calls: [], claimablePayoutFieldAvailable: false
        )
        for (mutation, _) in mutations {
            XCTAssertThrowsError(try builder.builder(for: mutation, capabilities: empty)) { error in
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
        }
    }

    func testMutationServiceGatesSubmissionOnPolicyDisclaimerAndFinalGuard() async throws {
        let executor = CovDPolkamarktExecutorSpy()
        var enabled = false
        var accepted = true
        var guardCalls = 0
        let authorizer = CovDPolkamarktAuthorizerStub {
            PolkamarktAuthorizedSubmission(builder: { $0 }, executor: executor, finalGuard: { guardCalls += 1 })
        }
        let service = PolkamarktMutationService(
            initialCapabilities: Self.complete,
            callBuilder: PolkamarktMutationCallBuilder(),
            submissionAuthorizer: authorizer,
            initialExecutor: executor,
            mutationsEnabled: { enabled },
            disclaimerAccepted: { accepted }
        )
        let mutation = PolkamarktMutation.claimTrader(marketId: "5")

        let fee = try await service.estimateFee(for: mutation)
        XCTAssertEqual(fee.fee, "7")
        XCTAssertEqual(executor.estimateCount, 1)

        do { _ = try await service.submit(mutation); XCTFail("paused") } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.actionsPaused.localizedDescription)
        }
        enabled = true
        accepted = false
        do { _ = try await service.submit(mutation); XCTFail("disclaimer") } catch {
            XCTAssertTrue(error.localizedDescription.contains("disclaimer"))
        }
        accepted = true
        let hash = try await service.submit(mutation)
        XCTAssertEqual(hash, "0xhash")
        XCTAssertEqual(guardCalls, 1)
        XCTAssertEqual(authorizer.authorizeCount, 1)

        authorizer.onAuthorize = { enabled = false }
        do { _ = try await service.submit(mutation); XCTFail("paused after authorization") } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.actionsPaused.localizedDescription)
        }
        enabled = true
        authorizer.onAuthorize = { accepted = false }
        do { _ = try await service.submit(mutation); XCTFail("disclaimer withdrawn") } catch {
            XCTAssertEqual(error.localizedDescription, "The current Polkaswap disclaimer has not been accepted.")
        }
        XCTAssertEqual(executor.submitCount, 1)
    }

    func testAccountCapabilityExplainsEveryMissingPrerequisite() {
        let key = AssetKey(ecosystem: "substrate", chainId: "c", assetId: "a")
        func capability(_ collateral: AssetKey?, _ fee: AssetKey?, _ spendable: BigUInt?, _ feeBalance: BigUInt?) -> PolkamarktAccountCapability {
            PolkamarktAccountCapability(
                hasSoraAccount: true, collateralAssetKey: collateral, feeAssetKey: fee,
                collateralSpendable: spendable, feeSpendable: feeBalance
            )
        }
        XCTAssertTrue(capability(nil, key, 1, 1).failureReason()?.contains("KUSD collateral asset") == true)
        XCTAssertTrue(capability(key, nil, 1, 1).failureReason()?.contains("XOR fee asset") == true)
        XCTAssertTrue(capability(key, key, 1, nil).failureReason()?.contains("XOR balance is unavailable") == true)
        XCTAssertTrue(capability(key, key, nil, 1).failureReason(requiredCollateral: 1)?.contains("KUSD balance is unavailable") == true)
        XCTAssertNil(capability(key, key, nil, 5).failureReason(requiredFee: 5))
    }

    func testAccountCapabilityProviderReadsAuthoritativeBalances() async throws {
        let chain = CovDFixtures.soraChain()
        let wallet = CovDFixtures.wallet()
        let service = CovDAccountInfoServiceStub()
        let kusd = try XCTUnwrap(CovDFixtures.chainAsset(chain, currencyId: CovDFixtures.kusdAssetId))
        let xor = try XCTUnwrap(CovDFixtures.chainAsset(chain, currencyId: CovDFixtures.xorAssetId))
        service.infos = [kusd.chainAssetId: AccountInfo(ethBalance: 500), xor.chainAssetId: AccountInfo(ethBalance: 9)]

        let full = await PolkamarktAccountCapabilityProvider(wallet: wallet, chain: chain, accountInfoRemoteService: service)
            .accountCapability()
        XCTAssertEqual(full.collateralSpendable, 500)
        XCTAssertEqual(full.feeSpendable, 9)
        XCTAssertEqual(full.collateralAssetKey, kusd.assetKey)
        XCTAssertNil(full.failureReason(requiredCollateral: 500, requiredFee: 9))

        service.error = CovDTestError.offline
        let failed = await PolkamarktAccountCapabilityProvider(wallet: wallet, chain: chain, accountInfoRemoteService: service)
            .accountCapability()
        XCTAssertTrue(failed.hasSoraAccount)
        XCTAssertNil(failed.feeSpendable)

        let noAccount = await PolkamarktAccountCapabilityProvider(
            wallet: CovDFixtures.wallet(substrate: false), chain: chain, accountInfoRemoteService: service
        ).accountCapability()
        XCTAssertFalse(noAccount.hasSoraAccount)
        XCTAssertEqual(noAccount.failureReason(), "Add a SORA account to use Polkamarkt.")

        let noAssets = CovDFixtures.soraChain(assets: [CovDFixtures.asset(id: "xor", symbol: "XOR", currencyId: CovDFixtures.xorAssetId)])
        let partial = await PolkamarktAccountCapabilityProvider(wallet: wallet, chain: noAssets, accountInfoRemoteService: service)
            .accountCapability()
        XCTAssertNil(partial.collateralAssetKey)
        XCTAssertNotNil(partial.feeAssetKey)
        XCTAssertEqual(service.fetchCount, 2)
    }
}

final class CovDPolkamarktExecutorSpy: PolkamarktMutationExtrinsicExecuting {
    private(set) var estimateCount = 0
    private(set) var submitCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        estimateCount += 1
        return RuntimeDispatchInfo(feeValue: BigUInt(7))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> String {
        submitCount += 1
        return "0xhash"
    }
}

final class CovDPolkamarktAuthorizerStub: PolkamarktMutationSubmissionAuthorizing {
    private let make: () -> PolkamarktAuthorizedSubmission
    var onAuthorize: () -> Void = {}
    private(set) var authorizeCount = 0

    init(make: @escaping () -> PolkamarktAuthorizedSubmission) {
        self.make = make
    }

    func authorize(_: PolkamarktMutation) async throws -> PolkamarktAuthorizedSubmission {
        authorizeCount += 1
        onAuthorize()
        return make()
    }
}
