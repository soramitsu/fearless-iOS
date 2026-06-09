import CryptoKit
import Cuckoo
import FearlessFoundation
import RobinHood
import Web3
import XCTest
@testable import fearless
import SSFModels
import SSFUtils

final class NetworkWorkerCompatibilityTests: XCTestCase {
    override func tearDown() {
        URLProtocolMock.requestHandler = nil
        super.tearDown()
    }

    func testPerformRequestAppliesSignerAndDecodesResponse() async throws {
        struct ResponseModel: Decodable, Equatable {
            let value: String
        }

        let signer = SignerSpy()
        let session = makeSession()
        let worker = NetworkWorkerDefault(session: session)

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signed"), "1")

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"value":"ok"}"#.data(using: .utf8)!
            return (response, body)
        }

        let config = RequestConfig(
            baseURL: URL(string: "https://example.com")!,
            method: .get,
            endpoint: "test",
            headers: nil,
            body: nil
        )
        config.signingType = .custom(signer: signer)

        let result: ResponseModel = try await worker.performRequest(with: config)

        XCTAssertEqual(result, .init(value: "ok"))
        XCTAssertTrue(signer.didSign)
    }

    func testPerformRequestReturnsRawDataForDataType() async throws {
        let expected = Data([0x01, 0x02, 0x03, 0x04])
        let session = makeSession()
        let worker = NetworkWorkerDefault(session: session)

        URLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, expected)
        }

        let config = RequestConfig(
            baseURL: URL(string: "https://example.com")!,
            method: .get,
            endpoint: "bytes",
            headers: nil,
            body: nil
        )

        let result: Data = try await worker.performRequest(with: config)
        XCTAssertEqual(result, expected)
    }

    func testPerformRequestWithCacheOptionsYieldsSingleCachedResponse() async throws {
        struct ResponseModel: Decodable, Equatable {
            let value: Int
        }

        let session = makeSession()
        let worker = NetworkWorkerDefault(session: session)

        URLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"value":7}"#.data(using: .utf8)!
            return (response, body)
        }

        let config = RequestConfig(
            baseURL: URL(string: "https://example.com")!,
            method: .get,
            endpoint: "cached",
            headers: nil,
            body: nil
        )

        let stream = try await worker.performRequest(
            with: config,
            withCacheOptions: .onAll
        ) as AsyncThrowingStream<CachedNetworkResponse<ResponseModel>, Error>

        var values: [ResponseModel] = []
        for try await cached in stream {
            values.append(cached.data)
        }

        XCTAssertEqual(values, [.init(value: 7)])
    }

    func testOKXDexAggregatorUsesInjectedBaseURLAndSigner() async throws {
        let signer = SignerSpy()
        let service = makeOKXService(
            baseURL: URL(string: "https://okx.example")!,
            signer: signer
        )

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://okx.example/api/v5/dex/aggregator/supported/chain"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signed"), "1")

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
              "code": "0",
              "data": [
                {
                  "chainId": 1,
                  "chainName": "Ethereum",
                  "dexTokenApproveAddress": "0xapprove"
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, body)
        }

        let result = try await service.fetchAvailableChains()

        XCTAssertTrue(signer.didSign)
        XCTAssertEqual(result.code, "0")
        XCTAssertEqual(result.data.first?.chainId, 1)
        XCTAssertEqual(result.data.first?.chainName, "Ethereum")
        XCTAssertEqual(result.data.first?.dexTokenApproveAddress, "0xapprove")
    }

    func testOKXDexAggregatorAddsQueryItemsForTokenRequests() async throws {
        let service = makeOKXService(baseURL: URL(string: "https://okx.example")!)

        URLProtocolMock.requestHandler = { request in
            let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.scheme, "https")
            XCTAssertEqual(components?.host, "okx.example")
            XCTAssertEqual(components?.path, "/api/v5/dex/aggregator/all-tokens")
            XCTAssertEqual(components?.queryItems, [URLQueryItem(name: "chainId", value: "137")])

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
              "code": "0",
              "data": [
                {
                  "decimals": "18",
                  "tokenContractAddress": "0xtoken",
                  "tokenLogoUrl": "https://example.com/token.png",
                  "tokenName": "Test Token",
                  "tokenSymbol": "TEST"
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, body)
        }

        let result = try await service.fetchAllTokens(
            parameters: OKXDexAllTokensRequestParameters(chainId: "137")
        )

        XCTAssertEqual(result.code, "0")
        XCTAssertEqual(result.data.first?.tokenContractAddress, "0xtoken")
        XCTAssertEqual(result.data.first?.tokenSymbol, "TEST")
    }

    func testOKXDexRequestSignerUsesInjectedCredentialsAndDate() throws {
        let credentialsSource = OKXDexSigningCredentialsSourceStub(
            okxApiKey: "api-key",
            okxSecretKey: "secret-key",
            okxPassphrase: "passphrase",
            okxProjectId: "project-id"
        )
        let fixedDate = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2024,
                    month: 5,
                    day: 23,
                    hour: 12,
                    minute: 34,
                    second: 56,
                    nanosecond: 789_000_000
                )
            )
        )
        let signer = OKXDexRequestSigner(
            credentialsSource: credentialsSource,
            dateProvider: { fixedDate }
        )
        let requestURL = URL(string: "https://www.okx.com/api/v5/dex/aggregator/quote?chainId=1")!
        let body = #"{"amount":"100"}"#.data(using: .utf8)!
        let config = RequestConfig(
            baseURL: URL(string: "https://www.okx.com")!,
            method: .post,
            endpoint: nil,
            headers: nil,
            body: body
        )
        var request = URLRequest(url: requestURL)

        try signer.sign(request: &request, config: config)

        let timestamp = "2024-05-23T12:34:56.789Z"
        let payload = timestamp + "POST" + "/api/v5/dex/aggregator/quote?chainId=1" + #"{"amount":"100"}"#
        XCTAssertEqual(request.value(forHTTPHeaderField: "OK-ACCESS-TIMESTAMP"), timestamp)
        XCTAssertEqual(request.value(forHTTPHeaderField: "OK-ACCESS-KEY"), "api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "OK-ACCESS-PASSPHRASE"), "passphrase")
        XCTAssertEqual(request.value(forHTTPHeaderField: "OK-ACCESS-PROJECT"), "project-id")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "OK-ACCESS-SIGN"),
            okxSignature(payload: payload, secretKey: "secret-key")
        )
    }

    func testNomisAccountStatisticsFetcherUsesInjectedBaseURLAndSigner() async throws {
        let signer = SignerSpy()
        let fetcher = NomisAccountStatisticsFetcher(
            networkWorker: NetworkWorkerDefault(session: makeSession()),
            signer: signer,
            configSource: NomisAccountStatisticsConfigSourceStub(
                nomisAccountScoreURL: URL(string: "https://nomis.example/wallet")!
            )
        )

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://nomis.example/wallet/sora-address/score"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signed"), "1")

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
              "data": {
                "score": 42.5,
                "address": "sora-address",
                "stats": {
                  "nativeBalanceUSD": 10.5,
                  "holdTokensBalanceUSD": 7.25,
                  "walletAge": 12,
                  "totalTransactions": 34,
                  "totalRejectedTransactions": 2,
                  "averageTransactionTime": 1.5,
                  "maxTransactionTime": 9.5,
                  "minTransactionTime": 0.5,
                  "scoredAt": null
                }
              }
            }
            """.data(using: .utf8)!
            return (response, body)
        }

        let result = try await fetcher.fetchStatistics(address: "sora-address")

        XCTAssertTrue(signer.didSign)
        XCTAssertEqual(result?.data?.score, Decimal(string: "42.5"))
        XCTAssertEqual(result?.data?.address, "sora-address")
        XCTAssertEqual(result?.data?.stats?.totalTransactions, 34)
    }

    func testNomisRequestSignerUsesInjectedCredentials() throws {
        let signer = NomisRequestSigner(
            credentialsSource: NomisSigningCredentialsSourceStub(
                nomisClientId: "client-id",
                nomisApiKey: "api-key"
            )
        )
        let config = RequestConfig(
            baseURL: URL(string: "https://nomis.example")!,
            method: .get,
            endpoint: nil,
            headers: nil,
            body: nil
        )
        var request = URLRequest(url: URL(string: "https://nomis.example/wallet/sora-address/score")!)

        try signer.sign(request: &request, config: config)

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ClientId"), "client-id")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "api-key")
    }

    func testAlchemyServiceUsesInjectedAPIKeyAndNetworkWorker() async throws {
        let service = AlchemyService(
            networkWorker: NetworkWorkerDefault(session: makeSession()),
            apiKeySource: AlchemyAPIKeySourceStub(alchemyApiKey: "alchemy-key")
        )

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://eth-mainnet.g.alchemy.com/v2/alchemy-key"
            )
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "transfers": []
              }
            }
            """.data(using: .utf8)!
            return (response, body)
        }

        let result = try await service.fetchTransactionHistory(
            request: AlchemyHistoryRequest(toAddress: "0xabc", category: [.external])
        )

        XCTAssertEqual(result.jsonrpc, "2.0")
        XCTAssertEqual(result.id, 1)
        XCTAssertTrue(result.result.transfers.isEmpty)
    }

    func testAlchemyNFTOperationFactoryUsesInjectedAPIKeyWhenBuildingURLs() throws {
        let factory = AlchemyNFTOperationFactory(
            apiKeySource: AlchemyAPIKeySourceStub(alchemyApiKey: "nft-key")
        )

        let url = try XCTUnwrap(factory.buildEndpointURL(
            baseURL: URL(string: "https://eth-mainnet.g.alchemy.com/nft/v2/")!,
            endpoint: "getNFTs",
            queryItems: [
                URLQueryItem(name: "owner", value: "0xabc"),
                URLQueryItem(name: "excludeFilters[]", value: "spam")
            ]
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "eth-mainnet.g.alchemy.com")
        XCTAssertEqual(components.path, "/nft/v2/nft-key/getNFTs")
        XCTAssertEqual(
            components.queryItems?.map { "\($0.name)=\($0.value ?? "")" },
            ["owner=0xabc", "excludeFilters[]=spam"]
        )
    }

    func testEtherscanHistoryOperationFactoryUsesInjectedBlockExplorerAPIKey() throws {
        let factory = EtherscanHistoryOperationFactory(
            apiKeySource: BlockExplorerAPIKeySourceStub(values: [.etherscan: "scan-key"])
        )

        let request = try XCTUnwrap(factory.buildRequest(
            address: "0xabc",
            url: URL(string: "https://api.etherscan.io/api")!,
            chainAsset: makeEthereumChainAsset(chainId: "1", ethereumType: .normal)
        ))
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(components.host, "api.etherscan.io")
        XCTAssertEqual(components.path, "/api")
        XCTAssertEqual(
            components.queryItems?.map { "\($0.name)=\($0.value ?? "")" },
            ["module=account", "action=txlist", "address=0xabc", "apikey=scan-key"]
        )
    }

    func testOklinkHistoryOperationFactoryUsesInjectedBlockExplorerAPIKeyHeader() throws {
        let factory = OklinkHistoryOperationFactory(
            apiKeySource: BlockExplorerAPIKeySourceStub(values: [.oklink: "oklink-key"])
        )

        let request = try XCTUnwrap(factory.buildRequest(
            address: "0xabc",
            url: URL(string: "https://www.oklink.com/api/v5/explorer/address/transaction-list")!,
            chainAsset: makeEthereumChainAsset(symbol: "USDT", ethereumType: .erc20)
        ))
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Ok-Access-Key"), "oklink-key")
        XCTAssertEqual(
            components.queryItems?.map { "\($0.name)=\($0.value ?? "")" },
            ["address=0xabc", "symbol=USDT", "protocolType=token_20"]
        )
    }

    func testPricesServiceUsesInjectedSubscriberAndDateProviderForThrottle() {
        let priceSubscriber = PriceLocalStorageSubscriberSpy()
        let dateProvider = PricesServiceDateProviderStub(now: Date(timeIntervalSince1970: 1000))
        let service = PricesService(
            chainRepository: AnyDataProviderRepository(InMemoryDataProviderRepository<ChainModel>()),
            walletRepository: AnyDataProviderRepository(InMemoryDataProviderRepository<MetaAccountModel>()),
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            eventCenter: EventCenter(syncQueue: DispatchQueue(label: "test.prices.events")),
            priceLocalSubscriber: priceSubscriber,
            dateProvider: dateProvider
        )
        let chainAsset = makeEthereumChainAsset(chainId: "1", ethereumType: .normal)
        let currency = Currency.defaultCurrency()

        service.observePrices(for: [chainAsset], currencies: [currency])
        dateProvider.now = Date(timeIntervalSince1970: 1010)
        service.observePrices(for: [chainAsset], currencies: [currency])
        dateProvider.now = Date(timeIntervalSince1970: 1031)
        service.observePrices(for: [chainAsset], currencies: [currency])

        XCTAssertEqual(priceSubscriber.priceSubscriptions.map { $0.chainAssetIds }, [
            [chainAsset.chainAssetId.id],
            [chainAsset.chainAssetId.id]
        ])
        XCTAssertEqual(priceSubscriber.priceSubscriptions.map(\.currencies), [
            [currency],
            [currency]
        ])
    }

    func testSoraSubqueryPriceFetcherUsesInjectedNetworkWorkerAndPiIndexer() throws {
        let chainAsset = makeSoraPriceChainAsset(
            pricingURL: URL(string: "https://pi.soramitsu.io/graphql")!
        )
        let fetcher = SoraSubqueryPriceFetcherDefault(
            worker: NetworkWorkerDefault(session: makeSession())
        )

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://pi.soramitsu.io/graphql")
            XCTAssertEqual(request.httpMethod, "POST")

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let bodyData = """
            {
              "data": {
                "entities": {
                  "edges": [
                    {
                      "node": {
                        "id": "xor",
                        "priceUSD": "1.23",
                        "priceChangeDay": -4.5
                      }
                    }
                  ],
                  "pageInfo": {
                    "hasNextPage": false,
                    "endCursor": null
                  }
                }
              }
            }
            """.data(using: .utf8)!
            return (response, bodyData)
        }

        let operation = fetcher.fetchPriceOperation(for: [chainAsset])
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let prices: [PriceData]
        switch operation.result {
        case let .success(result):
            prices = result
        case let .failure(error):
            throw error
        case .none:
            XCTFail("Expected SORA price fetch operation to complete")
            return
        }

        XCTAssertEqual(prices, [
            PriceData(
                currencyId: "usd",
                priceId: "xor",
                price: "1.23",
                fiatDayChange: Decimal(string: "-4.5"),
                coingeckoPriceId: "xor-gecko"
            )
        ])
    }

    func testPriceDataSourceUsesInjectedDependenciesAndUpdatesCurrencyFromEventCenter() throws {
        let eventCenter = PriceDataSourceEventCenterSpy()
        let coingeckoFactory = CoingeckoOperationFactoryStub(prices: [
            PriceData(
                currencyId: "usd",
                priceId: "xor-gecko",
                price: "2.00",
                fiatDayChange: 7,
                coingeckoPriceId: "xor-gecko"
            )
        ])
        let soraFetcher = SoraSubqueryPriceFetcherStub(prices: [
            PriceData(
                currencyId: "usd",
                priceId: "xor",
                price: "1.23",
                fiatDayChange: -4.5,
                coingeckoPriceId: "xor-gecko"
            )
        ])
        let chainRegistry = MockChainRegistryProtocol()
        stub(chainRegistry) { stub in
            stub.getEthereumConnection(for: any()).thenReturn(nil)
        }

        let chainAsset = makeSoraPriceChainAsset(
            pricingURL: URL(string: "https://pi.soramitsu.io/graphql")!
        )
        let source = PriceDataSource(
            currencies: [Currency.defaultCurrency()],
            chainAssets: [chainAsset],
            dependencies: PriceDataSourceDependencies(
                eventCenter: eventCenter,
                coingeckoOperationFactory: coingeckoFactory,
                chainlinkOperationFactory: ChainlinkOperationFactoryStub(),
                soraOperationFactory: soraFetcher,
                chainRegistry: chainRegistry
            )
        )

        XCTAssertTrue(eventCenter.addedObservers.contains { $0 === source })

        let wrapper = source.fetchOperation()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        let prices: [PriceData]
        switch wrapper.targetOperation.result {
        case let .success(result):
            prices = try XCTUnwrap(result)
        case let .failure(error):
            throw error
        case .none:
            XCTFail("Expected price data source operation to complete")
            return
        }

        XCTAssertEqual(prices, soraFetcher.prices)
        XCTAssertEqual(coingeckoFactory.requestedTokenIds, [["xor-gecko"]])
        XCTAssertEqual(coingeckoFactory.requestedCurrencies, [[Currency.defaultCurrency()]])
        XCTAssertEqual(soraFetcher.requestedChainAssetIds, [[chainAsset.chainAssetId.id]])

        let euroAccount = AccountGenerator.generateMetaAccount().replacingCurrency(.euro())
        MetaAccountModelChangedEvent(account: euroAccount).accept(visitor: try XCTUnwrap(eventCenter.addedObservers.first))

        XCTAssertEqual(source.identifier, "usd.eur")
    }

    func testPriceLocalStorageSubscriberUsesInjectedDependenciesForChainSync() {
        let chainAsset = makeSoraPriceChainAsset(
            pricingURL: URL(string: "https://pi.soramitsu.io/graphql")!
        )
        let fetchExpectation = expectation(description: "Fetch chains")
        let providerExpectation = expectation(description: "Create price provider")
        let eventCenter = PriceDataSourceEventCenterSpy()
        let chainsRepository = ChainModelRepositoryFetchingSpy(
            chains: [chainAsset.chain],
            expectation: fetchExpectation
        )
        let priceProviderFactory = RecordingPriceProviderFactory(
            expectation: providerExpectation
        )

        let subscriber = PriceLocalStorageSubscriberImpl(
            eventCenter: eventCenter,
            priceLocalSubscriber: priceProviderFactory,
            chainsRepository: chainsRepository,
            refreshChainsOnSetup: false
        )

        XCTAssertTrue(eventCenter.addedObservers.contains { $0 === subscriber })

        subscriber.processChainSyncDidComplete(event: ChainSyncDidComplete(
            newOrUpdatedChains: [chainAsset.chain],
            removedChains: []
        ))

        wait(for: [fetchExpectation, providerExpectation], timeout: 2)

        XCTAssertEqual(chainsRepository.fetchAllCallCount, 1)
        XCTAssertEqual(priceProviderFactory.requests, [
            RecordingPriceProviderFactory.Request(
                currencyIds: [],
                chainAssetIds: [chainAsset.chainAssetId.id]
            )
        ])
    }

    func testSubqueryStakingRewardsFetcherAssemblyUsesInjectedNetworkWorker() async throws {
        try await assertStakingRewardsFetcherUsesInjectedWorker(
            explorerType: .subquery,
            responseBody: """
            {
              "data": {
                "historyElements": {
                  "nodes": []
                }
              }
            }
            """
        )
    }

    func testSubsquidStakingRewardsFetcherAssemblyUsesInjectedNetworkWorker() async throws {
        try await assertStakingRewardsFetcherUsesInjectedWorker(
            explorerType: .subsquid,
            responseBody: """
            {
              "data": {
                "historyElements": []
              }
            }
            """
        )
    }

    func testGiantsquidStakingRewardsFetcherAssemblyUsesInjectedNetworkWorker() async throws {
        try await assertStakingRewardsFetcherUsesInjectedWorker(
            explorerType: .giantsquid,
            responseBody: """
            {
              "data": {
                "transfers": [],
                "stakingRewards": [],
                "bonds": [],
                "slashes": []
              }
            }
            """
        )
    }

    func testSoraStakingRewardsFetcherAssemblyUsesInjectedNetworkWorker() async throws {
        try await assertStakingRewardsFetcherUsesInjectedWorker(
            explorerType: .sora,
            responseBody: """
            {
              "data": {
                "transfers": [],
                "stakingRewards": [],
                "bonds": [],
                "slashes": []
              }
            }
            """
        )
    }

    func testReefStakingRewardsFetcherAssemblyUsesInjectedNetworkWorker() async throws {
        try await assertStakingRewardsFetcherUsesInjectedWorker(
            explorerType: .reef,
            responseBody: """
            {
              "data": {
                "stakingsConnection": {
                  "edges": [],
                  "totalCount": 0
                }
              }
            }
            """
        )
    }

    func testGitHubPhishingServiceFactoryUsesInjectedDependencies() {
        let configSource = RemoteSyncConfigSourceStub(
            phishingListURL: URL(string: "https://lists.example/phishing.json")!,
            scamListCsvURL: nil,
            polkaswapSettingsURL: nil
        )
        let operationFactory = CapturingGitHubOperationFactory()
        let operationManager = CapturingOperationManager()

        let service = GitHubPhishingServiceFactory.createService(
            dependencies: GitHubPhishingServiceFactoryDependencies(
                configSource: configSource,
                storageFacade: SubstrateStorageTestFacade(),
                operationFactory: operationFactory,
                operationManager: operationManager
            )
        )

        service.setup()

        XCTAssertEqual(operationFactory.requestedURLs, [configSource.phishingListURL])
        XCTAssertEqual(operationManager.enqueuedOperationCounts, [2])

        guard case .transient = operationManager.enqueuedModes.first else {
            XCTFail("Expected GitHub phishing service to enqueue transient operations")
            return
        }
    }

    func testScamSyncServiceFactoryUsesInjectedConfigAndFetcher() {
        let scamListCsvURL = URL(string: "https://lists.example/scams.csv")!
        let configSource = RemoteSyncConfigSourceStub(
            phishingListURL: URL(string: "https://lists.example/phishing.json")!,
            scamListCsvURL: scamListCsvURL,
            polkaswapSettingsURL: nil
        )
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let dataFetchFactory = CapturingDataOperationFactory()
        defer {
            operationQueue.cancelAllOperations()
            operationQueue.isSuspended = false
        }

        let service = ScamSyncServiceFactory.createService(
            dependencies: ScamSyncServiceFactoryDependencies(
                configSource: configSource,
                storageFacade: SubstrateStorageTestFacade(),
                dataFetchFactory: dataFetchFactory,
                retryStrategy: ExponentialReconnection(),
                operationQueue: operationQueue
            )
        )

        service.syncUp()

        XCTAssertEqual(dataFetchFactory.requestedURLs, [scamListCsvURL])
    }

    func testPolkaswapSettingsFactoryUsesInjectedConfigAndFetcher() {
        let polkaswapSettingsURL = URL(string: "https://lists.example/polkaswap.json")!
        let configSource = RemoteSyncConfigSourceStub(
            phishingListURL: URL(string: "https://lists.example/phishing.json")!,
            scamListCsvURL: nil,
            polkaswapSettingsURL: polkaswapSettingsURL
        )
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        let dataFetchFactory = CapturingDataOperationFactory()
        defer {
            operationQueue.cancelAllOperations()
            operationQueue.isSuspended = false
        }

        let service = PolkaswapSettingsFactory.createService(
            dependencies: PolkaswapSettingsFactoryDependencies(
                configSource: configSource,
                storageFacade: SubstrateStorageTestFacade(),
                dataFetchFactory: dataFetchFactory,
                retryStrategy: ExponentialReconnection(),
                operationQueue: operationQueue
            )
        )

        service.syncUp()

        XCTAssertEqual(dataFetchFactory.requestedURLs, [polkaswapSettingsURL])
    }

    func testSoraRewardOperationFactoryUsesInjectedLocalizationManager() throws {
        try assertRewardOperationFactoryUsesInjectedLocalizationManager(
            explorerType: .sora,
            expectedQueryFragment: "stakingRewards"
        )
    }

    func testGiantsquidRewardOperationFactoryUsesInjectedLocalizationManager() throws {
        try assertRewardOperationFactoryUsesInjectedLocalizationManager(
            explorerType: .giantsquid,
            expectedQueryFragment: "stakingRewards"
        )
    }

    func testSubsquidRewardOperationFactoryUsesInjectedLocalizationManager() throws {
        try assertRewardOperationFactoryUsesInjectedLocalizationManager(
            explorerType: .subsquid,
            expectedQueryFragment: "historyElements"
        )
    }

    private func assertStakingRewardsFetcherUsesInjectedWorker(
        explorerType: BlockExplorerType,
        responseBody: String
    ) async throws {
        let stakingURL = URL(string: "https://staking.example/\(explorerType.rawValue)")!
        let assembly = StakingRewardsFetcherAssembly(
            worker: NetworkWorkerDefault(session: makeSession()),
            localizationManager: NetworkWorkerLocalizationManagerStub(selectedLocalization: "en")
        )
        let fetcher = try assembly.fetcher(for: makeStakingRewardsChain(
            explorerType: explorerType,
            stakingURL: stakingURL
        ))

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, stakingURL.absoluteString)
            XCTAssertEqual(request.httpMethod, "POST")

            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseBody.utf8))
        }

        let rewards = try await fetcher.fetchAllRewards(
            address: "reward-address",
            startTimestamp: nil,
            endTimestamp: nil
        )

        XCTAssertTrue(rewards.isEmpty)
    }

    private func assertRewardOperationFactoryUsesInjectedLocalizationManager(
        explorerType: BlockExplorerType,
        expectedQueryFragment: String
    ) throws {
        let localizationManager = TrackingLocalizationManagerStub(selectedLocalization: "ja")
        let operationFactory = RewardOperationFactory.factory(
            chain: makeRewardChain(explorerType: explorerType),
            localizationManager: localizationManager
        )

        let operation = operationFactory.createHistoryOperation(
            address: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq",
            startTimestamp: 0,
            endTimestamp: 60
        )
        let query = try rewardQuery(from: operation)

        XCTAssertEqual(localizationManager.selectedLocalizationReadCount, 1)
        XCTAssertTrue(query.contains(expectedQueryFragment))
        XCTAssertTrue(query.contains("timestamp_gte:"))
        XCTAssertTrue(query.contains("timestamp_lte:"))
    }

    private func rewardQuery(from operation: BaseOperation<RewardOrSlashResponse>) throws -> String {
        let networkOperation = try XCTUnwrap(operation as? NetworkOperation<RewardOrSlashResponse>)
        let request = try networkOperation.requestFactory.createRequest()
        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        return try XCTUnwrap(json?["query"] as? String)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: configuration)
    }

    private func makeOKXService(
        baseURL: URL,
        signer: RequestSigner = SignerSpy()
    ) -> OKXDexAggregatorService {
        OKXDexAggregatorServiceImpl(
            networkWorker: NetworkWorkerDefault(session: makeSession()),
            signer: signer,
            configSource: OKXDexAggregatorConfigSourceStub(okxDexAggregatorURL: baseURL)
        )
    }

    private func okxSignature(payload: String, secretKey: String) -> String {
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(payload.utf8),
            using: SymmetricKey(data: Data(secretKey.utf8))
        )
        return Data(signature).base64EncodedString()
    }

    private func makeEthereumChainAsset(
        chainId: ChainModel.Id = "195",
        symbol: String = "ETH",
        ethereumType: EthereumAssetType?
    ) -> ChainAsset {
        let node = ChainNodeModel(
            url: URL(string: "https://node.example")!,
            name: "Node",
            apikey: nil
        )
        let asset = AssetModel(
            id: ethereumType == .normal ? "native" : "0xtoken",
            name: symbol,
            symbol: symbol,
            precision: 18,
            isUtility: ethereumType == .normal,
            isNative: ethereumType == .normal,
            ethereumType: ethereumType
        )
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            paraId: nil,
            name: "Ethereum",
            assets: [asset],
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            icon: nil,
            options: [.ethereumBased],
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeStakingRewardsChain(
        explorerType: BlockExplorerType,
        stakingURL: URL
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://staking-node.example")!,
            name: "Staking Node",
            apikey: nil
        )
        let externalApi = ChainModel.ExternalApiSet(
            staking: ChainModel.BlockExplorer(type: explorerType.rawValue, url: stakingURL)
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "staking-\(explorerType.rawValue)",
            paraId: nil,
            name: "Staking",
            assets: [],
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeSoraPriceChainAsset(pricingURL: URL) -> ChainAsset {
        let node = ChainNodeModel(
            url: URL(string: "https://sora-node.example")!,
            name: "SORA Node",
            apikey: nil
        )
        let asset = AssetModel(
            id: "xor",
            name: "XOR",
            symbol: "XOR",
            precision: 18,
            currencyId: "xor",
            isUtility: true,
            isNative: true,
            priceProvider: PriceProvider(type: .sorasubquery, id: "xor", precision: nil),
            coingeckoPriceId: "xor-gecko"
        )
        let externalApi = ChainModel.ExternalApiSet(
            pricing: ChainModel.BlockExplorer(type: "sora", url: pricingURL)
        )
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: "sora",
            paraId: nil,
            name: "SORA",
            assets: [asset],
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 69,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeRewardChain(explorerType: BlockExplorerType) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://node.example")!,
            name: "node",
            apikey: nil
        )
        let externalApi = ChainModel.ExternalApiSet(
            staking: ChainModel.BlockExplorer(
                type: explorerType.rawValue,
                url: URL(string: "https://staking.example/\(explorerType.rawValue)")!
            ),
            history: nil,
            crowdloans: nil,
            explorers: nil,
            pricing: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "reward-\(explorerType.rawValue)",
            paraId: nil,
            name: "Reward \(explorerType.rawValue)",
            assets: [],
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 42,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class NetworkWorkerLocalizationManagerStub: LocalizationManagerProtocol {
    var selectedLocalization: String
    let availableLocalizations: [String]

    init(selectedLocalization: String) {
        self.selectedLocalization = selectedLocalization
        availableLocalizations = [selectedLocalization]
    }

    func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping LocalizationChangeClosure
    ) {
        _ = owner
        _ = queue
        _ = closure
    }

    func removeObserver(by owner: AnyObject) {
        _ = owner
    }
}

private final class TrackingLocalizationManagerStub: LocalizationManagerProtocol {
    private var localization: String
    private(set) var selectedLocalizationReadCount = 0
    let availableLocalizations: [String]

    var selectedLocalization: String {
        get {
            selectedLocalizationReadCount += 1
            return localization
        }
        set {
            localization = newValue
        }
    }

    init(selectedLocalization: String) {
        localization = selectedLocalization
        availableLocalizations = [selectedLocalization]
    }

    func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping LocalizationChangeClosure
    ) {
        _ = owner
        _ = queue
        _ = closure
    }

    func removeObserver(by owner: AnyObject) {
        _ = owner
    }
}

private final class SignerSpy: RequestSigner {
    private(set) var didSign = false

    func sign(request: inout URLRequest, config _: RequestConfig) throws {
        didSign = true
        request.setValue("1", forHTTPHeaderField: "X-Signed")
    }
}

private struct OKXDexAggregatorConfigSourceStub: OKXDexAggregatorConfigSource {
    let okxDexAggregatorURL: URL
}

private struct OKXDexSigningCredentialsSourceStub: OKXDexRequestSigningCredentialsSource {
    let okxApiKey: String
    let okxSecretKey: String
    let okxPassphrase: String
    let okxProjectId: String
}

private struct NomisAccountStatisticsConfigSourceStub: NomisAccountStatisticsConfigSource {
    let nomisAccountScoreURL: URL
}

private struct NomisSigningCredentialsSourceStub: NomisRequestSigningCredentialsSource {
    let nomisClientId: String
    let nomisApiKey: String
}

private struct AlchemyAPIKeySourceStub: AlchemyAPIKeySource {
    let alchemyApiKey: String
}

private struct BlockExplorerAPIKeySourceStub: BlockExplorerAPIKeySource {
    let values: [BlockExplorerApiKey: String]

    func apiKey(for key: BlockExplorerApiKey) -> String {
        values[key] ?? ""
    }
}

private final class PricesServiceDateProviderStub: PricesServiceDateProvider {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private final class PriceLocalStorageSubscriberSpy: PriceLocalStorageSubscriber {
    struct PriceSubscription: Equatable {
        let chainAssetIds: [String]
        let currencies: [Currency]
    }

    private(set) var priceSubscriptions: [PriceSubscription] = []

    func subscribeToPrice(
        for chainAsset: ChainAsset,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrice(for: chainAsset, currencies: nil, listener: listener)
    }

    func subscribeToPrice(
        for chainAsset: ChainAsset,
        currencies: [Currency]?,
        listener _: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        priceSubscriptions.append(PriceSubscription(
            chainAssetIds: [chainAsset.chainAssetId.id],
            currencies: currencies ?? []
        ))

        return AnySingleValueProvider(SingleValueProviderStub(item: []))
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset],
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: chainAssets, currencies: nil, listener: listener)
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset],
        currencies: [Currency]?,
        listener _: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        priceSubscriptions.append(PriceSubscription(
            chainAssetIds: chainAssets.map(\.chainAssetId.id),
            currencies: currencies ?? []
        ))

        return AnySingleValueProvider(SingleValueProviderStub(item: []))
    }
}

private final class PriceDataSourceEventCenterSpy: EventCenterProtocol {
    private(set) var addedObservers: [EventVisitorProtocol] = []
    private(set) var removedObservers: [EventVisitorProtocol] = []
    private(set) var notifiedEvents: [EventProtocol] = []

    func notify(with event: EventProtocol) {
        notifiedEvents.append(event)
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        addedObservers.append(observer)
    }

    func remove(observer: EventVisitorProtocol) {
        removedObservers.append(observer)
    }
}

private final class CoingeckoOperationFactoryStub: CoingeckoOperationFactoryProtocol {
    let prices: [PriceData]
    private(set) var requestedTokenIds: [[String]] = []
    private(set) var requestedCurrencies: [[Currency]] = []

    init(prices: [PriceData]) {
        self.prices = prices
    }

    func fetchPriceOperation(
        for tokenIds: [String],
        currencies: [Currency]
    ) -> BaseOperation<[PriceData]> {
        requestedTokenIds.append(tokenIds)
        requestedCurrencies.append(currencies)

        return ClosureOperation { self.prices }
    }
}

private final class SoraSubqueryPriceFetcherStub: SoraSubqueryPriceFetcher {
    let prices: [PriceData]
    private(set) var requestedChainAssetIds: [[String]] = []

    init(prices: [PriceData]) {
        self.prices = prices
    }

    func fetchPriceOperation(for chainAssets: [ChainAsset]) -> BaseOperation<[PriceData]> {
        requestedChainAssetIds.append(chainAssets.map(\.chainAssetId.id))

        return ClosureOperation { self.prices }
    }
}

private final class ChainlinkOperationFactoryStub: ChainlinkOperationFactory {
    private(set) var requestedChainAssetIds: [String] = []

    func priceCall(for chainAsset: ChainAsset, connection _: Web3.Eth?) -> BaseOperation<PriceData>? {
        requestedChainAssetIds.append(chainAsset.chainAssetId.id)

        return nil
    }
}

private final class ChainModelRepositoryFetchingSpy: ChainModelRepositoryFetching {
    let chains: [ChainModel]
    let expectation: XCTestExpectation
    private(set) var fetchAllCallCount = 0

    init(chains: [ChainModel], expectation: XCTestExpectation) {
        self.chains = chains
        self.expectation = expectation
    }

    func fetchAll() async throws -> [ChainModel] {
        fetchAllCallCount += 1
        expectation.fulfill()

        return chains
    }
}

private final class RecordingPriceProviderFactory: PriceProviderFactoryProtocol {
    struct Request: Equatable {
        let currencyIds: [String]
        let chainAssetIds: [String]
    }

    let expectation: XCTestExpectation
    private(set) var requests: [Request] = []

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func getPricesProvider(
        currencies: [Currency]?,
        chainAssets: [ChainAsset]
    ) -> AnySingleValueProvider<[PriceData]> {
        requests.append(Request(
            currencyIds: currencies?.map(\.id) ?? [],
            chainAssetIds: chainAssets.map(\.chainAssetId.id)
        ))
        expectation.fulfill()

        return AnySingleValueProvider(SingleValueProviderStub(item: []))
    }
}

private struct RemoteSyncConfigSourceStub: PhishingListConfigSource, ScamListConfigSource, PolkaswapSettingsConfigSource {
    let phishingListURL: URL
    let scamListCsvURL: URL?
    let polkaswapSettingsURL: URL?
}

private final class CapturingGitHubOperationFactory: GitHubOperationFactoryProtocol {
    private(set) var requestedURLs: [URL] = []

    func fetchPhishingListOperation(_ url: URL) -> BaseOperation<[PhishingItem]> {
        requestedURLs.append(url)
        return ClosureOperation { [] }
    }
}

private final class CapturingOperationManager: OperationManagerProtocol {
    private(set) var enqueuedOperationCounts: [Int] = []
    private(set) var enqueuedModes: [OperationMode] = []

    func enqueue(operations: [Operation], in mode: OperationMode) {
        enqueuedOperationCounts.append(operations.count)
        enqueuedModes.append(mode)
    }
}

private final class CapturingDataOperationFactory: DataOperationFactoryProtocol {
    private(set) var requestedURLs: [URL] = []

    func fetchData(from url: URL) -> BaseOperation<Data> {
        requestedURLs.append(url)
        return ClosureOperation { Data() }
    }
}

private final class URLProtocolMock: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        _ = request
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = URLProtocolMock.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "URLProtocolMock", code: 0))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
