import Foundation
import XCTest
@testable import fearless

final class EtherscanHistoryOperationFactoryTests: XCTestCase {
    func testBscMainnetUsesChainBoundV2AndUnifiedKey() throws {
        let url = try EtherscanHistoryOperationFactory.historyURL(
            address: "0x1234567890123456789012345678901234567890",
            baseURL: try XCTUnwrap(URL(string: "https://api.bscscan.com/api")),
            chainId: "56",
            action: "tokentx",
            unifiedAPIKey: "unified-test-key"
        )

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "api.etherscan.io")
        XCTAssertEqual(url.path, "/v2/api")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
        XCTAssertEqual(query["chainid"], "56")
        XCTAssertEqual(query["module"], "account")
        XCTAssertEqual(query["action"], "tokentx")
        XCTAssertEqual(query["apikey"], "unified-test-key")
    }

    func testV2RejectsWrongRegistryChainAndMissingUnifiedKey() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://api.bscscan.com/api"))
        XCTAssertThrowsError(try EtherscanHistoryOperationFactory.historyURL(
            address: "0x1234567890123456789012345678901234567890",
            baseURL: baseURL, chainId: "1", action: "txlist",
            unifiedAPIKey: "unified-test-key"
        )) { XCTAssertEqual($0 as? EtherscanHistoryError, .invalidEndpoint) }
        XCTAssertThrowsError(try EtherscanHistoryOperationFactory.historyURL(
            address: "0x1234567890123456789012345678901234567890",
            baseURL: baseURL, chainId: "56", action: "txlist",
            unifiedAPIKey: ""
        )) { XCTAssertEqual($0 as? EtherscanHistoryError, .missingAPIKey) }
    }

    func testIndependentEtherscanCompatibleExplorerKeepsItsEndpoint() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://explorer.oasys.games/api"))
        let url = try EtherscanHistoryOperationFactory.historyURL(
            address: "0x1234567890123456789012345678901234567890",
            baseURL: baseURL, chainId: "248", action: "txlist",
            unifiedAPIKey: "unified-test-key"
        )
        XCTAssertEqual(url.host, "explorer.oasys.games")
        XCTAssertEqual(url.path, "/api")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertFalse(items.contains { $0.name == "chainid" || $0.name == "apikey" })
    }

    func testUnknownHistoryHostNeverReceivesUnifiedExplorerKey() throws {
        let url = try EtherscanHistoryOperationFactory.historyURL(
            address: "0x1234567890123456789012345678901234567890",
            baseURL: try XCTUnwrap(URL(string: "https://example.org/api")),
            chainId: "56", action: "txlist", unifiedAPIKey: "unified-test-key"
        )
        XCTAssertEqual(url.host, "example.org")
        XCTAssertFalse(url.absoluteString.contains("unified-test-key"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertFalse(items.contains { $0.name == "apikey" })
    }

    func testProviderErrorDoesNotDecodeAsEmptyHistory() throws {
        for json in [
            #"{"status":"0","message":"NOTOK","result":"Invalid API Key"}"#,
            #"{"status":"0","message":"NOTOK","result":[]}"#,
            #"{"status":"1","message":"OK","result":"Max rate limit reached"}"#,
            #"{"status":"0","message":"No transactions found","result":[{}]}"#,
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(
                EtherscanHistoryResponse.self, from: Data(json.utf8)
            )) { XCTAssertEqual($0 as? EtherscanHistoryError, .providerRejected) }
        }
    }

    func testExplicitNoTransactionsResponseIsEmpty() throws {
        for result in ["[]", #""No transactions found""#] {
            let json = #"{"status":"0","message":"No transactions found","result":\#(result)}"#
            let response = try JSONDecoder().decode(
                EtherscanHistoryResponse.self, from: Data(json.utf8)
            )
            XCTAssertTrue(response.result.isEmpty)
        }
    }

    func testSuccessfulTransactionStillDecodes() throws {
        let json = #"{"status":"1","message":"OK","result":[{"hash":"0xabc","timeStamp":"1710000000","value":"42","gas":"21000","gasPrice":"10","gasUsed":"21000"}]}"#
        let response = try JSONDecoder().decode(
            EtherscanHistoryResponse.self, from: Data(json.utf8)
        )
        XCTAssertEqual(response.result.count, 1)
        XCTAssertEqual(response.result.first?.hash, "0xabc")
        XCTAssertEqual(response.result.first?.timestampInSeconds, 1_710_000_000)
    }
}
