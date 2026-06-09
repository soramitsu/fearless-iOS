import XCTest
import BigInt
import SSFModels
import SSFUtils
@testable import fearless

final class CrowdloanListTests: XCTestCase {
    func testCrowdloanLastContribution_whenEncodedDecoded_thenRoundTripsSupportedCases() throws {
        let values: [CrowdloanLastContribution] = [
            .never,
            .preEnding(value: 42),
            .ending(blockNumber: 123_456)
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        try values.forEach { value in
            let encoded = try encoder.encode(value)
            let decoded = try decoder.decode(CrowdloanLastContribution.self, from: encoded)

            XCTAssertEqual(decoded, value)
        }
    }

    func testCrowdloanLastContribution_whenDecodedFromInvalidPayload_thenThrows() throws {
        let decoder = JSONDecoder()
        let payloads = [
            #"["PreEnding","not-int"]"#,
            #"["Ending","not-int"]"#,
            #"["Unknown",null]"#
        ]

        try payloads.forEach { payload in
            let data = try XCTUnwrap(payload.data(using: .utf8))

            XCTAssertThrowsError(try decoder.decode(CrowdloanLastContribution.self, from: data))
        }
    }

    func testMoonbeamFlow_whenDataOmitsOptionalFields_thenKeepsProvidedUrlsAndUsesDefaults() throws {
        let payload = """
        {
          "paraid": "2002",
          "name": "Moonbeam",
          "token": "GLMR",
          "description": "Ethereum-compatible smart contract parachain on Polkadot",
          "website": "https://moonbeam.network",
          "icon": "https://raw.githubusercontent.com/polkadot-js/apps/master/packages/apps-config/src/ui/logos/nodes/moonbeam.png",
          "flow": {
            "name": "moonbeam",
            "data": {
              "devApiUrl": "https://wallet-test.api.purestake.xyz",
              "prodApiUrl": "https://wallet-test.api.purestake.xyz"
            }
          }
        }
        """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let displayInfo = try JSONDecoder().decode(CrowdloanDisplayInfo.self, from: data)

        guard case let .moonbeam(flowData)? = displayInfo.flowIfSupported else {
            return XCTFail("Expected Moonbeam custom flow")
        }

        XCTAssertEqual(flowData.devApiUrl, "https://wallet-test.api.purestake.xyz")
        XCTAssertEqual(flowData.prodApiUrl, "https://wallet-test.api.purestake.xyz")
        XCTAssertEqual(flowData.termsUrl, MoonbeamFlowData.default.termsUrl)
        XCTAssertEqual(flowData.devApiKey, MoonbeamFlowData.default.devApiKey)
        XCTAssertEqual(flowData.prodApiKey, MoonbeamFlowData.default.prodApiKey)
    }

    func testMoonbeamFlow_whenDataProvidesApiKeys_thenUsesProvidedValues() throws {
        let payload = """
        {
          "paraid": "2002",
          "name": "Moonbeam",
          "token": "GLMR",
          "description": "Ethereum-compatible smart contract parachain on Polkadot",
          "website": "https://moonbeam.network",
          "icon": "https://raw.githubusercontent.com/polkadot-js/apps/master/packages/apps-config/src/ui/logos/nodes/moonbeam.png",
          "flow": {
            "name": "moonbeam",
            "data": {
              "devApiUrl": "https://dev.example.com",
              "prodApiUrl": "https://prod.example.com",
              "devApiKey": "remote-dev-key",
              "prodApiKey": "remote-prod-key"
            }
          }
        }
        """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let displayInfo = try JSONDecoder().decode(CrowdloanDisplayInfo.self, from: data)

        guard case let .moonbeam(flowData)? = displayInfo.flowIfSupported else {
            return XCTFail("Expected Moonbeam custom flow")
        }

        XCTAssertEqual(flowData.devApiUrl, "https://dev.example.com")
        XCTAssertEqual(flowData.prodApiUrl, "https://prod.example.com")
        XCTAssertEqual(flowData.devApiKey, "remote-dev-key")
        XCTAssertEqual(flowData.prodApiKey, "remote-prod-key")
    }

    func testCreateViewModel_whenCrowdloansHaveDifferentStates_thenSplitsActiveAndCompletedSections() throws {
        let currentBlock: BlockNumber = 1337
        let active = try makeCrowdloan(
            paraId: 2000,
            raised: 100,
            cap: 1000,
            end: currentBlock + 100,
            trieIndex: 1
        )
        let ended = try makeCrowdloan(
            paraId: 2001,
            raised: 100,
            cap: 1000,
            end: currentBlock,
            trieIndex: 2
        )
        let won = try makeCrowdloan(
            paraId: 2002,
            raised: 100,
            cap: 1000,
            end: currentBlock + 100,
            trieIndex: 3
        )
        let viewInfo = CrowdloansViewInfo(
            contributions: [:],
            leaseInfo: [
                2002: ParachainLeaseInfo(
                    paraId: 2002,
                    fundAccountId: Data(repeating: 12, count: 32),
                    leasedAmount: 1000
                )
            ],
            displayInfo: [
                2000: makeDisplayInfo(paraId: 2000, name: "Active parachain"),
                2001: makeDisplayInfo(paraId: 2001, name: "Ended parachain"),
                2002: makeDisplayInfo(paraId: 2002, name: "Won parachain")
            ],
            metadata: CrowdloanMetadata(
                blockNumber: currentBlock,
                blockDuration: 6,
                leasingPeriod: 1000,
                leasingOffset: 0
            )
        )
        let chainAsset = ChainAssetDisplayInfo(
            asset: makeAsset().displayInfo,
            chain: .substrate(42)
        )
        let factory = CrowdloansViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory(),
            iconGenerator: nil
        )

        let viewModel = factory.createViewModel(
            from: [ended, active, won],
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(viewModel.tokenSymbol, "UNIT")
        XCTAssertEqual(viewModel.active?.crowdloans.map(\.paraId), [2000])
        XCTAssertEqual(Set(viewModel.completed?.crowdloans.map(\.paraId) ?? []), [2001, 2002])
        XCTAssertEqual(viewModel.active?.crowdloans.first?.content.title, "Active parachain")
        XCTAssertEqual(
            Set(viewModel.completed?.crowdloans.map(\.content.title) ?? []),
            ["Ended parachain", "Won parachain"]
        )
    }

    private func makeCrowdloan(
        paraId: ParaId,
        raised: BigUInt,
        cap: BigUInt,
        end: BlockNumber,
        trieIndex: TrieIndex
    ) throws -> Crowdloan {
        let depositor = Data(repeating: UInt8(paraId % 255), count: 32)
        let payload = """
        {
          "depositor": "\(depositor.base64EncodedString())",
          "deposit": "100",
          "raised": "\(raised)",
          "end": "\(end)",
          "cap": "\(cap)",
          "lastContribution": ["Never", null],
          "firstPeriod": "2",
          "lastPeriod": "3",
          "trieIndex": "\(trieIndex)"
        }
        """
        let data = try XCTUnwrap(payload.data(using: .utf8))
        let fundInfo = try JSONDecoder().decode(CrowdloanFunds.self, from: data)

        return Crowdloan(paraId: paraId, fundInfo: fundInfo)
    }

    private func makeDisplayInfo(paraId: ParaId, name: String) -> CrowdloanDisplayInfo {
        CrowdloanDisplayInfo(
            paraid: "\(paraId)",
            name: name,
            token: "UNIT",
            description: "\(name) description",
            website: "https://example.com/\(paraId)",
            icon: "https://example.com/\(paraId).png",
            rewardRate: nil,
            endingBlock: nil,
            disabled: nil,
            flow: nil
        )
    }

    private func makeAsset() -> AssetModel {
        AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            isUtility: true,
            isNative: true,
            type: .normal
        )
    }
}
