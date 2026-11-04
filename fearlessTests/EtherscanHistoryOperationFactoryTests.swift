@testable import fearless
import Foundation
import RobinHood
import SoraFoundation
import SSFModels
import XCTest

final class EtherscanHistoryOperationFactoryTests: XCTestCase {
    private let owner = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    private let peer = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    private let contract = "0xcccccccccccccccccccccccccccccccccccccccc"
    private var native: AssetModel {
        AssetModel(id: "native-avax-id", name: "Avalanche", symbol: "AVAX", precision: 18, isUtility: true, isNative: false, ethereumType: .normal)
    }

    private var token: AssetModel {
        AssetModel(id: contract, name: "Token", symbol: "TOKEN", precision: 6, isUtility: false, isNative: false, ethereumType: .erc20)
    }

    override func tearDown() {
        EtherscanURLProtocol.handler = nil
        super.tearDown()
    }

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

    func testV2PaginationKeepsChainIdFirstAndUnifiedKeyLast() throws {
        let url = try EtherscanHistoryOperationFactory.historyURL(
            address: owner,
            baseURL: XCTUnwrap(URL(string: "https://api.bscscan.com/api")),
            chainId: "56",
            action: "tokentx",
            unifiedAPIKey: "unified-test-key",
            additionalQueryItems: [
                URLQueryItem(name: "contractaddress", value: contract),
                URLQueryItem(name: "page", value: "3"),
                URLQueryItem(name: "offset", value: "100"),
                URLQueryItem(name: "sort", value: "desc")
            ]
        )
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(url.host, "api.etherscan.io")
        XCTAssertEqual(items.map(\.name), [
            "chainid", "module", "action", "address", "contractaddress", "page", "offset", "sort", "apikey"
        ])
        XCTAssertEqual(items.first?.value, "56")
        XCTAssertEqual(items.last?.value, "unified-test-key")
    }

    func testAssemblyUsesAvalancheRoutescanAndRequestNeverContainsAnotherProvidersKey() throws {
        let storage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> = SubstrateDataStorageFacade.shared.createRepository()
        XCTAssertTrue(HistoryOperationFactoriesAssembly.createOperationFactory(chain: try avalancheChain(), txStorage: AnyDataProviderRepository(storage)) is EtherscanHistoryOperationFactory)
        let factory = EtherscanHistoryOperationFactory(baseURL: EtherscanHistoryOperationFactory.avalancheHistoryURL)
        let request = try factory.makeRequest(asset: token, chain: avalancheChain(), address: owner, pagination: Pagination(count: 200))
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.host, "api.routescan.io")
        XCTAssertEqual(url.path, "/v2/network/mainnet/evm/43114/etherscan/api")
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["module"], "account")
        XCTAssertEqual(values["action"], "tokentx")
        XCTAssertEqual(values["contractaddress"], contract)
        XCTAssertEqual(values["offset"], "100")
        XCTAssertEqual(values["sort"], "desc")
        XCTAssertEqual(values["page"], "1")
        // Routescan is not an Etherscan V2 host: no chain binding and no explorer key.
        XCTAssertNil(values["apikey"])
        XCTAssertNil(values["chainid"])
        XCTAssertThrowsError(try factory.makeRequest(asset: native, chain: avalancheChain(), address: owner, pagination: Pagination(count: 0))) {
            XCTAssertEqual($0 as? EtherscanHistoryError, .invalidEndpoint)
        }
    }

    func testCursorRejectsDifferentAccountAssetChainOrPageSize() throws {
        let factory = EtherscanHistoryOperationFactory(baseURL: EtherscanHistoryOperationFactory.avalancheHistoryURL)
        let valid = ["etherscanPage": "2", "chainId": "43114", "address": owner, "assetId": native.id, "limit": "10"]
        let request = try factory.makeRequest(asset: native, chain: avalancheChain(), address: owner.uppercased(), pagination: Pagination(count: 10, context: valid))
        XCTAssertTrue(request.url?.query?.contains("page=2") == true)
        for (key, value) in [("etherscanPage", "0"), ("etherscanPage", String(Int.max)), ("chainId", "56"), ("address", peer), ("assetId", contract), ("limit", "20")] {
            var invalid = valid
            invalid[key] = value
            XCTAssertThrowsError(try factory.makeRequest(asset: native, chain: avalancheChain(), address: owner, pagination: Pagination(count: 10, context: invalid))) {
                XCTAssertEqual($0 as? EtherscanHistoryError, .invalidCursor)
            }
        }
    }

    func testPaginationCursorRoundTripRequestsTheNextPageForTheSameScope() async throws {
        let (factory, session) = makeFactory()
        defer { session.invalidateAndCancel() }
        var requestedPages: [String?] = []
        EtherscanURLProtocol.handler = { request in
            let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
            requestedPages.append(items.first { $0.name == "page" }?.value)
            XCTAssertEqual(items.first { $0.name == "offset" }?.value, "1")
            return (200, self.payload())
        }
        let first = try await factory.fetchPage(asset: native, chain: avalancheChain(), address: owner, pagination: Pagination(count: 1))
        XCTAssertEqual(first.transactions.map(\.transactionId), ["0x123"])
        let context = try XCTUnwrap(first.context)
        XCTAssertEqual(context, ["etherscanPage": "2", "chainId": "43114", "address": owner, "assetId": native.id, "limit": "1"])
        let second = try await factory.fetchPage(asset: native, chain: avalancheChain(), address: owner, pagination: Pagination(count: 1, context: context))
        XCTAssertEqual(second.context?["etherscanPage"], "3")
        XCTAssertEqual(requestedPages, ["1", "2"])
    }

    func testPaginationAdvancesUsingRemoteCountEvenWhenAssetFilterRemovesRows() async throws {
        let (factory, session) = makeFactory()
        defer { session.invalidateAndCancel() }
        EtherscanURLProtocol.handler = { _ in (200, self.payload(contract: self.peer)) }
        let page = try await factory.fetchPage(asset: token, chain: avalancheChain(), address: owner, pagination: Pagination(count: 1))
        XCTAssertTrue(page.transactions.isEmpty)
        XCTAssertEqual(page.context?["etherscanPage"], "2")
        EtherscanURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.query?.contains("page=2") == true)
            return (200, Data("{\"status\":\"0\",\"message\":\"No transactions found\",\"result\":[]}".utf8))
        }
        let last = try await factory.fetchPage(asset: token, chain: avalancheChain(), address: owner, pagination: Pagination(count: 1, context: page.context))
        XCTAssertTrue(last.transactions.isEmpty)
        XCTAssertNil(last.context)
    }

    func testNativeMappingPreservesAssetIdentifierCaseInsensitivePeerAndFailureStatus() async throws {
        let (factory, session) = makeFactory()
        defer { session.invalidateAndCancel() }
        EtherscanURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.query?.contains("action=txlist") == true)
            return (200, self.payload(failed: true))
        }
        let page = try await factory.fetchPage(asset: native, chain: avalancheChain(), address: owner.uppercased(), pagination: Pagination(count: 10))
        let transaction = try XCTUnwrap(page.transactions.first)
        XCTAssertEqual(transaction.assetId, native.id)
        XCTAssertEqual(transaction.peerName, peer)
        XCTAssertEqual(transaction.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(transaction.status, .rejected)
        XCTAssertEqual(transaction.amount.decimalValue, 1)
        XCTAssertEqual(transaction.fees.first?.assetId, native.id)
        XCTAssertNil(page.context)
    }

    func testFailedReceiptStatusIsRejectedAndPreByzantiumReceiptIsCommitted() throws {
        let chain = try avalancheChain()
        for (fields, expected) in [
            (#""isError":"0","txreceipt_status":"0""#, AssetTransactionStatus.rejected),
            (#""isError":"1","txreceipt_status":"1""#, .rejected),
            (#""isError":"0","txreceipt_status":"1""#, .commited),
            (#""isError":"0","txreceipt_status":"""#, .commited),
            (#""contractAddress":"\#(contract)""#, .commited)
        ] {
            let json = #"{"hash":"0x1","timeStamp":"1788652801","from":"\#(owner)","to":"\#(peer)","value":"1","gas":"1","gasPrice":"1","gasUsed":"1",\#(fields)}"#
            let element = try JSONDecoder().decode(EtherscanHistoryElement.self, from: Data(json.utf8))
            let transaction = AssetTransactionData.createTransaction(from: element, address: owner, chain: chain, asset: native)
            XCTAssertEqual(transaction.status, expected, fields)
        }
    }

    func testHTTPAndProviderErrorsNeverBecomeEmptyHistory() async throws {
        let (factory, session) = makeFactory()
        defer { session.invalidateAndCancel() }
        for (status, body, expected) in [
            (401, "{\"status\":\"1\",\"message\":\"OK\",\"result\":[]}", EtherscanHistoryError.invalidHTTPResponse),
            (200, "{\"status\":\"0\",\"message\":\"NOTOK\",\"result\":[]}", .providerRejected),
            (200, "{\"status\":\"0\",\"message\":\"NOTOK\",\"result\":\"private-key-rejected\"}", .providerRejected)
        ] {
            EtherscanURLProtocol.handler = { _ in (status, Data(body.utf8)) }
            do {
                _ = try await factory.fetchPage(asset: native, chain: avalancheChain(), address: owner, pagination: Pagination(count: 10))
                XCTFail("API error became an empty history")
            } catch {
                XCTAssertEqual(error as? EtherscanHistoryError, expected)
                XCTAssertFalse(error.localizedDescription.contains("private-key"))
            }
        }
    }

    func testTransportErrorDoesNotExposeTheRequestURL() async throws {
        let (factory, session) = makeFactory()
        defer { session.invalidateAndCancel() }
        EtherscanURLProtocol.handler = nil
        do {
            _ = try await factory.fetchPage(asset: native, chain: avalancheChain(), address: owner, pagination: Pagination(count: 10))
            XCTFail("Transport failure became an empty history")
        } catch {
            XCTAssertEqual(error as? EtherscanHistoryError, .requestFailed)
            XCTAssertFalse(error.localizedDescription.contains("routescan"))
        }
    }

    func testOperationWrapperAndExcludedFilter() throws {
        let (factory, session) = makeFactory()
        defer { session.invalidateAndCancel() }
        EtherscanURLProtocol.handler = { _ in (200, self.payload()) }
        let wrapper = factory.fetchTransactionHistoryOperation(asset: native, chain: try avalancheChain(), address: owner, filters: [], pagination: Pagination(count: 10))
        let done = expectation(description: "Routescan history")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [done], timeout: 10)
        XCTAssertEqual(try wrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)?.transactions.count, 1)
        let excluded = factory.fetchTransactionHistoryOperation(asset: native, chain: try avalancheChain(), address: owner, filters: [.init(type: .transfer, selected: false)], pagination: Pagination(count: 10))
        XCTAssertTrue(try excluded.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)?.transactions.isEmpty == true)
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

    func testUnavailableHistoryWithRecoveryShowsOneServiceErrorAndBothActions() {
        let controller = WalletTransactionHistoryViewController(
            presenter: HistoryPresenterFixture(),
            localizationManager: LocalizationManager.shared
        )
        controller.loadViewIfNeeded()
        controller.didReceive(state: .unavailable)
        controller.didReceiveHistoryFailure(canViewExplorer: true)

        let languages = controller.selectedLocale.rLanguages
        // The notice carries the message, so the empty state does not repeat it or claim an empty history.
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertFalse(controller.rootView.recoveryView.isHidden)
        XCTAssertEqual(
            controller.rootView.recoveryLabel.text,
            R.string.localizable.walletTransactionHistoryErrorMessage(preferredLanguages: languages)
        )
        XCTAssertFalse(controller.rootView.retryButton.isHidden)
        XCTAssertFalse(controller.rootView.explorerButton.isHidden)
        XCTAssertEqual(
            controller.rootView.explorerButton.title(for: .normal),
            R.string.localizable.walletTransactionHistoryViewExplorer(preferredLanguages: languages)
        )
        XCTAssertEqual(controller.numberOfSections(in: controller.rootView.tableView), 0)
    }

    func testUnsupportedHistoryRecoveryExplainsTheNetworkInsteadOfAnOutage() {
        let controller = WalletTransactionHistoryViewController(
            presenter: HistoryPresenterFixture(),
            localizationManager: LocalizationManager.shared
        )
        controller.loadViewIfNeeded()
        controller.didReceive(state: .unsupported)
        controller.didReceiveHistoryFailure(canViewExplorer: false)

        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertEqual(
            controller.rootView.recoveryLabel.text,
            R.string.localizable.walletTransactionHistoryUnsupportedMessage(
                preferredLanguages: controller.selectedLocale.rLanguages
            )
        )
        XCTAssertTrue(controller.rootView.explorerButton.isHidden)

        controller.didReceive(state: .unavailable)
        XCTAssertTrue(controller.rootView.recoveryView.isHidden)
        controller.didReceiveHistoryFailure(canViewExplorer: true)
        XCTAssertEqual(
            controller.rootView.recoveryLabel.text,
            R.string.localizable.walletTransactionHistoryErrorMessage(
                preferredLanguages: controller.selectedLocale.rLanguages
            )
        )
    }

    func testUnsupportedHistoryWithAnExplorerOffersTheExplorerAndNoPointlessRetry() {
        let controller = WalletTransactionHistoryViewController(
            presenter: HistoryPresenterFixture(),
            localizationManager: LocalizationManager.shared
        )
        controller.loadViewIfNeeded()
        controller.didReceive(state: .unsupported)
        controller.didReceiveHistoryFailure(canViewExplorer: true)

        XCTAssertFalse(controller.rootView.recoveryView.isHidden)
        XCTAssertFalse(controller.rootView.explorerButton.isHidden)
        XCTAssertTrue(controller.rootView.retryButton.isHidden, "retrying an unsupported network gives the same answer")

        // A provider outage can pass, so Retry comes back next to the explorer.
        controller.didReceive(state: .unavailable)
        controller.didReceiveHistoryFailure(canViewExplorer: true)
        XCTAssertFalse(controller.rootView.retryButton.isHidden)
        XCTAssertFalse(controller.rootView.explorerButton.isHidden)
    }

    private func makeFactory() -> (EtherscanHistoryOperationFactory, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EtherscanURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let factory = EtherscanHistoryOperationFactory(
            baseURL: EtherscanHistoryOperationFactory.avalancheHistoryURL,
            session: session
        )
        return (factory, session)
    }

    private func payload(contract: String = "", failed: Bool = false) -> Data {
        Data("""
        {"status":"1","message":"OK","result":[{"hash":"0x123","timeStamp":"1788652801","from":"\(owner)","to":"\(peer)","contractAddress":"\(contract)","value":"1000000000000000000","gas":"21000","gasPrice":"1","gasUsed":"21000","isError":"\(failed ? "1" : "0")"}]}
        """.utf8)
    }

    private func avalancheChain() throws -> ChainModel {
        let explorer = try XCTUnwrap(ChainModel.BlockExplorer(
            type: "etherscan",
            url: XCTUnwrap(URL(string: "https://www.oklink.com/api/v5/explorer/address/transaction-list?chainShortName=AVAXC"))
        ))
        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "43114",
            paraId: nil,
            name: "Avalanche",
            assets: [native],
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            options: [.ethereum],
            externalApi: .init(history: explorer),
            iosMinAppVersion: nil,
            identityChain: nil
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

    func testOKLinkRejectsHTTPAndProviderErrorsBeforeMapping() throws {
        let url = try XCTUnwrap(URL(string: "https://www.oklink.com/api/history"))
        for status in [401, 429, 500] {
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            XCTAssertThrowsError(try OklinkHistoryOperationFactory.decodeResponse(Data("{\"code\":\"0\",\"msg\":\"\",\"data\":[]}".utf8), response: response)) {
                XCTAssertEqual($0 as? OklinkHistoryError, .invalidHTTPResponse)
            }
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        XCTAssertThrowsError(try OklinkHistoryOperationFactory.decodeResponse(Data("{\"code\":\"50111\",\"msg\":\"Invalid API key\",\"data\":[]}".utf8), response: response)) {
            XCTAssertEqual($0 as? OklinkHistoryError, .providerRejected)
        }
        XCTAssertThrowsError(try OklinkHistoryOperationFactory.decodeResponse(nil, response: response))
        XCTAssertTrue(try OklinkHistoryOperationFactory.decodeResponse(Data("{\"code\":\"0\",\"msg\":\"\",\"data\":[]}".utf8), response: response).data.isEmpty)
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

    func retryHistory() {}
    func viewHistoryOnExplorer() {}

    func didSelect(viewModel _: WalletTransactionHistoryCellViewModel) {}
    func didTapFiltersButton() {}
}

private final class EtherscanURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let (status, data) = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
