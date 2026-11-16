import XCTest
import BigInt
@testable import fearless

final class CovJFinCrowdloanModelsTests: XCTestCase {
    private func displayInfo(paraId: String = "2000", endingBlock: UInt32? = nil, disabled: Bool? = nil, flow: String? = nil) throws -> CrowdloanDisplayInfo {
        let ending = endingBlock.map { "\($0)" } ?? "null"
        let disabledText = disabled.map { $0 ? "true" : "false" } ?? "null"
        let json = """
        {"paraid":"\(paraId)","name":"Acala","token":"ACA","description":"Crowdloan","website":"https://acala.invalid",
        "icon":"https://acala.invalid/icon.svg","rewardRate":3.5,"endingBlock":\(ending),"disabled":\(disabledText),
        "flow":\(flow ?? "null")}
        """
        return try JSONDecoder().decode(CrowdloanDisplayInfo.self, from: Data(json.utf8))
    }

    private func flow(_ json: String) throws -> CustomCrowdloanFlow {
        try JSONDecoder().decode(CustomCrowdloanFlow.self, from: Data(json.utf8))
    }

    private func roundTrip(_ flow: CustomCrowdloanFlow) throws -> CustomCrowdloanFlow {
        try JSONDecoder().decode(CustomCrowdloanFlow.self, from: JSONEncoder().encode(flow))
    }

    private func metadata(block: UInt32, period: UInt32 = 100, offset: UInt32 = 0) -> CrowdloanMetadata {
        CrowdloanMetadata(blockNumber: block, blockDuration: 6000, leasingPeriod: period, leasingOffset: offset)
    }

    func testLeasingIndexHandlesOffsetAndZeroPeriod() {
        XCTAssertEqual(metadata(block: 250, period: 100, offset: 0).leasingIndex, 2)
        XCTAssertEqual(metadata(block: 250, period: 100, offset: 40).leasingIndex, 2)
        XCTAssertEqual(metadata(block: 250, period: 100, offset: 60).leasingIndex, 1)
        XCTAssertEqual(metadata(block: 30, period: 100, offset: 40).leasingIndex, 0)
        XCTAssertEqual(metadata(block: 250, period: 0, offset: 0).leasingIndex, 0)
    }

    func testCrowdloanCompletionRulesAndRemainingTime() throws {
        let open = Crowdloan(paraId: 2000, fundInfo: try CovJFinCrowdloanFixture.funds(raised: 50, cap: 100, end: 1000, firstPeriod: 10))
        XCTAssertFalse(open.isCompleted(for: metadata(block: 900), displayInfo: nil))
        XCTAssertFalse(open.isCompleted(for: metadata(block: 900), displayInfo: try displayInfo(endingBlock: 950, disabled: false)))
        XCTAssertTrue(open.isCompleted(for: metadata(block: 900), displayInfo: try displayInfo(disabled: true)))
        XCTAssertTrue(open.isCompleted(for: metadata(block: 900), displayInfo: try displayInfo(endingBlock: 900)))
        XCTAssertTrue(open.isCompleted(for: metadata(block: 1000), displayInfo: nil))
        XCTAssertTrue(open.isCompleted(for: metadata(block: 900, period: 80), displayInfo: nil), "leasing index 11 is past period 10")

        let full = Crowdloan(paraId: 2001, fundInfo: try CovJFinCrowdloanFixture.funds(raised: 100, cap: 100))
        XCTAssertTrue(full.isCompleted(for: metadata(block: 1), displayInfo: nil))

        XCTAssertEqual(open.remainedTime(at: 900, blockDuration: 6000), 600, accuracy: 0.001)
        XCTAssertEqual(open.remainedTime(at: 1100, blockDuration: 6000), 0)
    }

    func testContributionResponsesBecomeADictionaryOfFundedEntries() throws {
        let account = Data(repeating: 1, count: 32)
        let responses = [
            CrowdloanContributionResponse(accountId: account, trieOrFundIndex: .trieIndex(1), contribution: try CovJFinCrowdloanFixture.contribution(balance: 10)),
            CrowdloanContributionResponse(accountId: account, trieOrFundIndex: .fundIndex(2), contribution: nil),
            CrowdloanContributionResponse(accountId: account, trieOrFundIndex: .fundIndex(3), contribution: try CovJFinCrowdloanFixture.contribution(balance: 30))
        ]
        let dict = responses.toDict()
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict[.trieIndex(1)]?.balance, 10)
        XCTAssertNil(dict[.fundIndex(2)])
        XCTAssertEqual(dict[.fundIndex(3)]?.balance, 30)
        XCTAssertTrue([CrowdloanContributionResponse]().toDict().isEmpty)
    }

    func testDisplayInfoListMapsByParaIdAndFiltersUnsupportedFlows() throws {
        let karura = try displayInfo(paraId: "2000", flow: "{\"name\":\"karura\"}")
        let unknown = try displayInfo(paraId: "2001", flow: "{\"name\":\"polkadex\"}")
        let plain = try displayInfo(paraId: "2002")
        let invalid = try displayInfo(paraId: "not-a-number")

        XCTAssertEqual(karura.flowIfSupported, .karura)
        XCTAssertNil(unknown.flowIfSupported)
        XCTAssertNotNil(unknown.flow)
        XCTAssertNil(plain.flowIfSupported)
        XCTAssertEqual(karura.rewardRate, Decimal(string: "3.5"))

        let map = [karura, unknown, plain, invalid].toMap()
        XCTAssertEqual(Set(map.keys), [2000, 2001, 2002])
        XCTAssertEqual(map[2000], karura)
        XCTAssertEqual(map[2002]?.name, "Acala")
    }

    func testFlowPropertiesForEveryCase() {
        let flows: [CustomCrowdloanFlow] = [
            .unsupported("polkadex"), .karura, .bifrost, .moonbeam(.default), .astar(.default), .moonbeamMemoFix("memo")
        ]
        XCTAssertEqual(flows.map(\.name), ["polkadex", "karura", "bifrost", "moonbeam", "astar", ""])
        XCTAssertEqual(flows.map(\.hasReferralBonus), [false, true, true, false, true, false])
        XCTAssertEqual(flows.map(\.hasEthereumReferral), [false, false, false, true, false, true])
        XCTAssertEqual(flows.map(\.needsContribute), [true, true, true, true, true, false])
    }

    func testFlowDecodingUsesProvidedDataOrDefaults() throws {
        XCTAssertEqual(try flow("{\"name\":\"karura\"}"), .karura)
        XCTAssertEqual(try flow("{\"name\":\"bifrost\"}"), .bifrost)
        XCTAssertEqual(try flow("{\"name\":\"astar\"}"), .astar(.default))
        XCTAssertEqual(
            try flow("{\"name\":\"astar\",\"data\":{\"fearlessReferral\":\"ref\",\"bonusRate\":0.5,\"referralRate\":0.25}}"),
            .astar(AstarFlowData(fearlessReferral: "ref", bonusRate: Decimal(string: "0.5"), referralRate: Decimal(string: "0.25")))
        )
        XCTAssertEqual(try flow("{\"name\":\"moonbeam\"}"), .moonbeam(.default))
        let moonbeam = MoonbeamFlowData(prodApiUrl: "https://prod.invalid", devApiUrl: "https://dev.invalid",
                                        termsUrl: "https://terms.invalid", devApiKey: "dev", prodApiKey: "prod")
        let moonbeamJSON = "{\"name\":\"moonbeam\",\"data\":{\"prodApiUrl\":\"https://prod.invalid\",\"devApiUrl\":\"https://dev.invalid\","
            + "\"termsUrl\":\"https://terms.invalid\",\"devApiKey\":\"dev\",\"prodApiKey\":\"prod\"}}"
        XCTAssertEqual(try flow(moonbeamJSON), .moonbeam(moonbeam))
        XCTAssertEqual(try flow("{\"name\":\"other\"}").name, "other")
        XCTAssertThrowsError(try flow("{\"title\":\"karura\"}"))
    }

    func testFlowEncodingRoundTripsAndEquality() throws {
        XCTAssertEqual(try roundTrip(.karura), .karura)
        XCTAssertEqual(try roundTrip(.bifrost), .bifrost)
        let astar = AstarFlowData(fearlessReferral: "ref", bonusRate: 1, referralRate: Decimal(string: "0.5"))
        XCTAssertEqual(try roundTrip(.astar(astar)), .astar(astar))
        XCTAssertEqual(try roundTrip(.moonbeam(.default)), .moonbeam(.default))
        XCTAssertEqual(try roundTrip(.unsupported("custom")).name, "custom")
        XCTAssertEqual(try roundTrip(.moonbeamMemoFix("memo")).name, "")

        XCTAssertEqual(CustomCrowdloanFlow.moonbeamMemoFix("a"), .moonbeamMemoFix("b"))
        XCTAssertNotEqual(CustomCrowdloanFlow.karura, .bifrost)
        XCTAssertNotEqual(CustomCrowdloanFlow.astar(.default), .astar(AstarFlowData(fearlessReferral: nil, bonusRate: nil, referralRate: nil)))
        XCTAssertEqual(AstarFlowData.default.fearlessReferral, "14Q22opa2mR3SsCZkHbDoSkN6iQpJPk6dDYwaQibufh41g3k")
        XCTAssertEqual(MoonbeamFlowData.default.prodApiUrl, "https://yy9252r9jh.api.purestake.io")
    }
}
