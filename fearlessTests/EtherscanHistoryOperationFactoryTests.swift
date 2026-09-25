@testable import fearless
import Foundation
import SoraFoundation
import XCTest

final class EtherscanHistoryOperationFactoryTests: XCTestCase {
    func testBscMainnetUsesChainBoundV2AndUnifiedKey() throws {
        let url = try EtherscanHistoryOperationFactory.historyURL(
            address: "0x1234567890123456789012345678901234567890",
            baseURL: XCTUnwrap(URL(string: "https://api.bscscan.com/api")),
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
            baseURL: XCTUnwrap(URL(string: "https://example.org/api")),
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
            #"{"status":"0","message":"No transactions found","result":[{}]}"#
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
        let json = #"""
        {"status":"1","message":"OK","result":[{
          "hash":"0xabc","timeStamp":"1710000000","value":"42",
          "gas":"21000","gasPrice":"10","gasUsed":"21000"
        }]}
        """#
        let response = try JSONDecoder().decode(
            EtherscanHistoryResponse.self, from: Data(json.utf8)
        )
        XCTAssertEqual(response.result.count, 1)
        XCTAssertEqual(response.result.first?.hash, "0xabc")
        XCTAssertEqual(response.result.first?.timestampInSeconds, 1_710_000_000)
    }

    func testUnavailableHistoryShowsServiceErrorInsteadOfEmptyHistory() {
        let controller = WalletTransactionHistoryViewController(
            presenter: HistoryPresenterFixture(),
            localizationManager: LocalizationManager.shared
        )
        controller.loadViewIfNeeded()
        controller.didReceive(state: .unavailable)

        XCTAssertTrue(controller.shouldDisplayEmptyState)
        XCTAssertEqual(
            controller.titleForEmptyState,
            R.string.localizable.walletTransactionHistoryErrorMessage(
                preferredLanguages: controller.selectedLocale.rLanguages
            )
        )
        XCTAssertNotEqual(
            controller.titleForEmptyState,
            R.string.localizable.walletTransactionHistoryEmptyMessage(
                preferredLanguages: controller.selectedLocale.rLanguages
            )
        )
    }
}

final class HistoryProviderFailureTests: XCTestCase {
    func testOklinkProviderErrorCannotBecomeEmptyHistory() throws {
        let failure = try JSONDecoder().decode(
            OklinkHistoryResponse.self,
            from: Data(#"{"code":"500","msg":"rate limited","data":[]}"#.utf8)
        )
        XCTAssertThrowsError(try failure.validatedData()) {
            XCTAssertEqual($0 as? OklinkHistoryError, .providerRejected)
        }
        let empty = try JSONDecoder().decode(
            OklinkHistoryResponse.self,
            from: Data(#"{"code":"0","msg":"","data":[]}"#.utf8)
        )
        XCTAssertTrue(try empty.validatedData().isEmpty)
    }
}

final class KaiaScanHistoryOperationFactoryTests: XCTestCase {
    private let address = "0x1234567890123456789012345678901234567890"
    private let contract = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"

    private func decode(_ json: String) throws -> KaiaHistoryResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(KaiaHistoryResponse.self, from: Data(json.utf8))
    }

    func testLegacyScopeMainnetRoutesToNativeKaiaScanWithBearerKey() throws {
        let source = try XCTUnwrap(URL(string: "https://scope.klaytn.com/api/v1"))
        let result = try KaiaHistoryOperationFactory.historyRequest(
            address: address,
            route: .init(configuredURL: source, chainId: "8217"),
            tokenContract: nil,
            pagination: Pagination(count: 20),
            apiKey: "synthetic-kaia-key"
        )
        XCTAssertEqual(result.page, 1)
        XCTAssertEqual(result.request.url?.host, "mainnet-oapi.kaiascan.io")
        XCTAssertEqual(result.request.url?.path, "/api/v1/accounts/\(address)/transactions")
        XCTAssertEqual(result.request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-kaia-key")
        let requestURL = try XCTUnwrap(result.request.url)
        let query = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value) })["page"], "1")
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value) })["size"], "20")
        XCTAssertFalse(try XCTUnwrap(result.request.url).absoluteString.contains("synthetic-kaia-key"))
    }

    func testKaiaTokenRouteBindsContractAndNextPage() throws {
        let source = try XCTUnwrap(URL(string: "https://mainnet-oapi.kaiascan.io/api/v1"))
        let result = try KaiaHistoryOperationFactory.historyRequest(
            address: address,
            route: .init(configuredURL: source, chainId: "8217"),
            tokenContract: contract,
            pagination: Pagination(count: 20, context: ["kaiaPage": "2"]),
            apiKey: "synthetic-kaia-key"
        )
        XCTAssertEqual(result.page, 2)
        XCTAssertEqual(result.request.url?.path, "/api/v1/accounts/\(address)/token-transfers")
        let requestURL = try XCTUnwrap(result.request.url)
        let query = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value) })
        XCTAssertEqual(values["page"], "2")
        XCTAssertEqual(values["contractAddress"], contract)
    }

    func testWrongKaiaNetworkUntrustedEndpointAndMissingKeyFailClosed() throws {
        let source = try XCTUnwrap(URL(string: "https://mainnet-oapi.kaiascan.io/api/v1"))
        let params = Pagination(count: 20)
        XCTAssertThrowsError(try KaiaHistoryOperationFactory.historyRequest(
            address: address, route: .init(configuredURL: source, chainId: "1001"),
            tokenContract: nil, pagination: params, apiKey: "synthetic-kaia-key"
        )) { XCTAssertEqual($0 as? KaiaHistoryError, .invalidEndpoint) }
        let untrusted = try XCTUnwrap(URL(string: "https://scope.klaytn.com.evil.example/api/v1"))
        XCTAssertThrowsError(try KaiaHistoryOperationFactory.historyRequest(
            address: address,
            route: .init(configuredURL: untrusted, chainId: "8217"),
            tokenContract: nil, pagination: params, apiKey: "synthetic-kaia-key"
        )) { XCTAssertEqual($0 as? KaiaHistoryError, .invalidEndpoint) }
        XCTAssertThrowsError(try KaiaHistoryOperationFactory.historyRequest(
            address: address, route: .init(configuredURL: source, chainId: "8217"),
            tokenContract: nil, pagination: params, apiKey: ""
        )) { XCTAssertEqual($0 as? KaiaHistoryError, .missingAPIKey) }
        XCTAssertThrowsError(try KaiaHistoryOperationFactory.historyRequest(
            address: address, route: .init(configuredURL: source, chainId: "8217"),
            tokenContract: nil, pagination: Pagination(count: 20, context: ["kaiaPage": "0"]),
            apiKey: "synthetic-kaia-key"
        )) { XCTAssertEqual($0 as? KaiaHistoryError, .invalidPagination) }
    }

    func testNativeAmountsFeesAndStatusRemainExactDecimals() throws {
        let json = #"""
        {"results":[{
          "transaction_hash":"0xabc","datetime":"2026-07-23T04:55:58.177Z",
          "from":"0x1234567890123456789012345678901234567890",
          "to":"0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
          "amount":0.123456789012345678,"transaction_fee":0.000042000000000001,
          "status":{"status":"Success"}
        }],"paging":{"total_count":1,"current_page":1,"last":true,"total_page":1}}
        """#
        let result = try decode(json).validatedTransactions(page: 1, address: address, tokenContract: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.amount, Decimal(string: "0.123456789012345678"))
        XCTAssertEqual(result.first?.transactionFee, Decimal(string: "0.000042000000000001"))
        XCTAssertEqual(result.first?.timestampInSeconds, 1_784_782_558)
        XCTAssertEqual(result.first?.status?.status, "Success")
    }

    func testTokenTransferBindsAccountAndContractWithoutInventingNetworkFee() throws {
        let json = #"""
        {"results":[{
          "transaction_hash":"0xabc","datetime":"2026-07-23T04:55:58.177Z",
          "from":"0x1234567890123456789012345678901234567890",
          "to":"0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
          "amount":42.123456789012345678,
          "contract":{"contract_address":"0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"}
        }],"paging":{"total_count":2,"current_page":2,"last":false,"total_page":3}}
        """#
        let result = try decode(json).validatedTransactions(page: 2, address: address, tokenContract: contract)
        XCTAssertEqual(result.first?.amount, Decimal(string: "42.123456789012345678"))
        XCTAssertNil(result.first?.transactionFee)
    }

    func testFeePayerOnlyActivityDoesNotBecomeAnIncomingTransfer() throws {
        let json = #"""
        {"results":[{
          "transaction_hash":"0xfee-only","datetime":"2026-07-23T04:55:58.177Z",
          "from":"0x1111111111111111111111111111111111111111",
          "to":"0x2222222222222222222222222222222222222222",
          "fee_payer":"0x1234567890123456789012345678901234567890",
          "amount":5,"transaction_fee":0.001,
          "status":{"status":"Success"}
        },{
          "transaction_hash":"0xreceived","datetime":"2026-07-23T04:56:58.177Z",
          "from":"0x1111111111111111111111111111111111111111",
          "to":"0x1234567890123456789012345678901234567890",
          "amount":2,"transaction_fee":0.001,
          "status":{"status":"Success"}
        }],"paging":{"total_count":2,"current_page":1,"last":true,"total_page":1}}
        """#
        let result = try decode(json).validatedTransactions(page: 1, address: address, tokenContract: nil)
        XCTAssertEqual(result.map(\.transactionHash), ["0xreceived"])
    }

    func testProviderFailureAndWrongContractCannotAppearAsEmptyHistory() throws {
        for json in [
            #"{"success":false,"code":500,"result":[]}"#,
            #"{"results":[],"paging":{"total_count":1,"current_page":1,"last":false,"total_page":2}}"#,
            #"{"results":[],"paging":{"total_count":0,"current_page":2,"last":true,"total_page":0}}"#
        ] {
            if let response = try? decode(json) {
                XCTAssertThrowsError(try response.validatedTransactions(
                    page: 1, address: address, tokenContract: nil
                )) {
                    XCTAssertEqual($0 as? KaiaHistoryError, .providerRejected)
                }
            } else {
                XCTAssertThrowsError(try decode(json))
            }
        }
        let wrongContract = #"""
        {"results":[{
          "transaction_hash":"0xabc","datetime":"2026-07-23T04:55:58.177Z",
          "from":"0x1234567890123456789012345678901234567890",
          "to":"0xabcdefabcdefabcdefabcdefabcdefabcdefabcd","amount":1.5,
          "contract":{"contract_address":"0x1111111111111111111111111111111111111111"}
        }],"paging":{"total_count":1,"current_page":1,"last":true,"total_page":1}}
        """#
        XCTAssertThrowsError(try decode(wrongContract).validatedTransactions(
            page: 1, address: address, tokenContract: contract
        )) {
            XCTAssertEqual($0 as? KaiaHistoryError, .providerRejected)
        }
        let unrelatedAccount = #"""
        {"results":[{
          "transaction_hash":"0xabc","datetime":"2026-07-23T04:55:58.177Z",
          "from":"0x1111111111111111111111111111111111111111",
          "to":"0x2222222222222222222222222222222222222222","amount":1.5,
          "contract":{"contract_address":"0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"}
        }],"paging":{"total_count":1,"current_page":1,"last":true,"total_page":1}}
        """#
        XCTAssertThrowsError(try decode(unrelatedAccount).validatedTransactions(
            page: 1, address: address, tokenContract: contract
        )) {
            XCTAssertEqual($0 as? KaiaHistoryError, .providerRejected)
        }
        let empty = try decode(
            #"{"results":[],"paging":{"total_count":0,"current_page":1,"last":true,"total_page":0}}"#
        )
        XCTAssertTrue(try empty.validatedTransactions(page: 1, address: address, tokenContract: nil).isEmpty)
        let documentedEmpty = try decode(
            #"{"results":[],"paging":{"total_count":0,"current_page":0,"last":true,"total_page":0}}"#
        )
        XCTAssertTrue(try documentedEmpty.validatedTransactions(page: 1, address: address, tokenContract: nil).isEmpty)
    }
}

private final class HistoryPresenterFixture: WalletTransactionHistoryPresenterProtocol {
    func setup(with _: WalletTransactionHistoryViewProtocol) {}
    func loadNext() -> Bool {
        false
    }

    func didSelect(viewModel _: WalletTransactionHistoryCellViewModel) {}
    func didTapFiltersButton() {}
    func didChangeFiltersSliderValue(index _: Int) {}
}
