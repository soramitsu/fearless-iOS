import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class SoraSubqueryPriceFetcherTests: XCTestCase {
    private let piEndpoint = URL(string: "https://pi.soramitsu.io/graphql")!
    private let staleRegistryEndpoint = URL(string: "https://api.subquery.network/sq/sora-xor/sora-prod")!

    override func tearDown() {
        SoraPriceURLProtocolMock.requestHandler = nil
        AssetPriceCache.shared.removeAll()
        super.tearDown()
    }

    func testProductionEndpointIsExactPolkaswapIndexerURL() {
        XCTAssertEqual(ApplicationConfig.shared.polkaswapIndexerURL, piEndpoint)
        XCTAssertEqual(ApplicationConfig.shared.polkaswapIndexerURL.scheme, "https")
        XCTAssertEqual(ApplicationConfig.shared.polkaswapIndexerURL.host, "pi.soramitsu.io")
        XCTAssertEqual(ApplicationConfig.shared.polkaswapIndexerURL.path, "/graphql")
    }

    func testFetchUsesFixedPIEndpointAndMapsSyntheticPrice() throws {
        let priceId = "0x0200000000000000000000000000000000000000000000000000000000000000"
        let chainAsset = makeChainAsset(priceId: priceId, currencyId: "774441749")
        let fetcher = makeFetcher()

        SoraPriceURLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.url, self.piEndpoint)
            XCTAssertNotEqual(request.url, self.staleRegistryEndpoint)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try self.requestBody(request)
            XCTAssertEqual(body.operationName, "FearlessFiatPrices")
            XCTAssertEqual(body.first, 100)
            XCTAssertNil(body.after)
            XCTAssertEqual(body.ids, [priceId])
            XCTAssertTrue(body.query.contains("$ids: [String!]!"))

            return try self.response(
                nodes: [[
                    "id": priceId,
                    "priceUSD": "12.3456",
                    "priceChangeDay": 1.25
                ]],
                hasNextPage: false,
                endCursor: "complete"
            )
        }

        let prices = try execute(fetcher.fetchPriceOperation(for: [chainAsset]))

        XCTAssertEqual(
            prices,
            [
                PriceData(
                    currencyId: "usd",
                    priceId: priceId,
                    price: "12.3456",
                    fiatDayChange: Decimal(string: "1.25"),
                    coingeckoPriceId: "coingecko-\(priceId)"
                )
            ]
        )
    }

    func testRequestUsesVariablesForUntrustedIdentifiersAndFiltersOtherProviders() throws {
        let untrustedPriceId = "asset\") { __typename } #\nnext"
        let soraAsset = makeChainAsset(priceId: untrustedPriceId)
        let coingeckoAsset = makeChainAsset(priceId: "polkadot", providerType: .coingecko)
        let fetcher = makeFetcher()

        SoraPriceURLProtocolMock.requestHandler = { request in
            let body = try self.requestBody(request)
            XCTAssertEqual(body.ids, [untrustedPriceId])
            XCTAssertFalse(body.query.contains(untrustedPriceId))
            XCTAssertFalse(body.ids.contains("polkadot"))

            return try self.response(
                nodes: [[
                    "id": untrustedPriceId,
                    "priceUSD": "9.5",
                    "priceChangeDay": 0
                ]],
                hasNextPage: false,
                endCursor: nil
            )
        }

        let prices = try execute(
            fetcher.fetchPriceOperation(for: [coingeckoAsset, soraAsset, soraAsset])
        )

        XCTAssertEqual(prices.map(\.priceId), [untrustedPriceId])
    }

    func testPaginationUsesReturnedCursorAndRejectsRepeatedCursor() throws {
        let priceIds = ["asset-a", "asset-b", "asset-c"]
        let chainAssets = priceIds.map { makeChainAsset(priceId: $0) }
        let fetcher = makeFetcher()
        let recorder = RequestRecorder()

        SoraPriceURLProtocolMock.requestHandler = { request in
            let body = try self.requestBody(request)
            let requestIndex = recorder.append(body)

            switch requestIndex {
            case 0:
                return try self.response(
                    nodes: [["id": "asset-a", "priceUSD": "1", "priceChangeDay": 0]],
                    hasNextPage: true,
                    endCursor: "same-cursor"
                )
            case 1:
                return try self.response(
                    nodes: [["id": "asset-b", "priceUSD": "2", "priceChangeDay": 0]],
                    hasNextPage: true,
                    endCursor: "same-cursor"
                )
            default:
                XCTFail("Fetcher requested an unbounded third page")
                return try self.response(nodes: [], hasNextPage: false, endCursor: nil)
            }
        }

        XCTAssertThrowsError(try execute(fetcher.fetchPriceOperation(for: chainAssets))) { error in
            guard case SubqueryPriceFetcherError.invalidPagination = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let bodies = recorder.values
        XCTAssertEqual(bodies.count, 2)
        guard bodies.count == 2 else {
            return
        }
        XCTAssertNil(bodies[0].after)
        XCTAssertEqual(bodies[1].after, "same-cursor")
        XCTAssertEqual(bodies[0].ids, priceIds)
        XCTAssertEqual(bodies[1].ids, priceIds)
    }

    func testInvalidEndpointFailsBeforeNetworkAccess() throws {
        let recorder = RequestRecorder()
        let fetcher = SoraSubqueryPriceFetcherDefault(
            endpoint: staleRegistryEndpoint,
            session: makeSession()
        )

        SoraPriceURLProtocolMock.requestHandler = { request in
            _ = recorder.append(try self.requestBody(request))
            return try self.response(nodes: [], hasNextPage: false, endCursor: nil)
        }

        XCTAssertThrowsError(
            try execute(fetcher.fetchPriceOperation(for: [makeChainAsset(priceId: "asset-a")]))
        ) { error in
            guard case SubqueryPriceFetcherError.invalidEndpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(recorder.values.isEmpty)
    }

    func testNonPositiveMalformedAndMissingPIPricesAreNotPresented() throws {
        let invalidPriceIds = [
            "zero",
            "negative",
            "malformed",
            "numeric-prefix",
            "multiple-decimals",
            "embedded-space",
            "missing"
        ]
        let positivePriceId = "positive"
        let fetcher = makeFetcher()

        SoraPriceURLProtocolMock.requestHandler = { _ in
            try self.response(
                nodes: [
                    ["id": "zero", "priceUSD": "0", "priceChangeDay": 0],
                    ["id": "negative", "priceUSD": "-1.5", "priceChangeDay": 0],
                    ["id": "malformed", "priceUSD": "not-a-price", "priceChangeDay": 0],
                    ["id": "numeric-prefix", "priceUSD": "1abc", "priceChangeDay": 0],
                    ["id": "multiple-decimals", "priceUSD": "1.2.3", "priceChangeDay": 0],
                    ["id": "embedded-space", "priceUSD": "1 2", "priceChangeDay": 0],
                    ["id": "missing", "priceUSD": NSNull(), "priceChangeDay": NSNull()],
                    ["id": positivePriceId, "priceUSD": "0.0001", "priceChangeDay": 0]
                ],
                hasNextPage: false,
                endCursor: nil
            )
        }

        let prices = try execute(
            fetcher.fetchPriceOperation(
                for: (invalidPriceIds + [positivePriceId]).map {
                    makeChainAsset(priceId: $0)
                }
            )
        )

        XCTAssertEqual(prices.map(\.priceId), [positivePriceId])
        XCTAssertEqual(prices.first?.price, "0.0001")
    }

    func testNoSoraAssetsCompletesWithoutNetworkAccess() throws {
        let recorder = RequestRecorder()
        let fetcher = makeFetcher()

        SoraPriceURLProtocolMock.requestHandler = { request in
            _ = recorder.append(try self.requestBody(request))
            return try self.response(nodes: [], hasNextPage: false, endCursor: nil)
        }

        let prices = try execute(
            fetcher.fetchPriceOperation(
                for: [makeChainAsset(priceId: "polkadot", providerType: .coingecko)]
            )
        )

        XCTAssertTrue(prices.isEmpty)
        XCTAssertTrue(recorder.values.isEmpty)
    }

    func testPriceSnapshotIsVisibleOnlyForItsExactFiatCurrency() throws {
        let priceId = "asset-price-id"
        let usdPrice = PriceData(
            currencyId: "usd",
            priceId: priceId,
            price: "7.25",
            fiatDayChange: Decimal(string: "-0.5"),
            coingeckoPriceId: "synthetic-coingecko-id"
        )
        let asset = makeChainAsset(priceId: priceId).asset

        AssetPriceCache.shared.merge([usdPrice])

        XCTAssertEqual(asset.getPrice(for: .defaultCurrency()), usdPrice)
        XCTAssertNil(asset.getPrice(for: .euro()))
    }

    func testNarrowOrStaleSnapshotCannotEraseValidPrices() throws {
        let firstPriceId = "first-price-id"
        let secondPriceId = "second-price-id"
        let firstAsset = makeChainAsset(priceId: firstPriceId).asset
        let secondAsset = makeChainAsset(priceId: secondPriceId).asset
        let firstPrice = PriceData(
            currencyId: "usd",
            priceId: firstPriceId,
            price: "7.25",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )
        let secondPrice = PriceData(
            currencyId: "usd",
            priceId: secondPriceId,
            price: "9.5",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )
        let updatedFirstPrice = PriceData(
            currencyId: "usd",
            priceId: firstPriceId,
            price: "8.25",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )

        AssetPriceCache.shared.merge([firstPrice])
        AssetPriceCache.shared.merge([secondPrice])
        AssetPriceCache.shared.merge([updatedFirstPrice])

        XCTAssertEqual(firstAsset.getPrice(for: .defaultCurrency()), updatedFirstPrice)
        XCTAssertEqual(secondAsset.getPrice(for: .defaultCurrency()), secondPrice)
    }

    func testPartialPIResponseUsesCoinGeckoFallbackPerMissingProviderId() {
        let firstAsset = makeChainAsset(
            priceId: "pi-first",
            coingeckoPriceId: "cg-first"
        )
        let secondAsset = makeChainAsset(
            priceId: "pi-second",
            coingeckoPriceId: "cg-second"
        )
        let coingeckoPrices = [
            PriceData(
                currencyId: "usd",
                priceId: "cg-first",
                price: "1",
                fiatDayChange: 1,
                coingeckoPriceId: "cg-first"
            ),
            PriceData(
                currencyId: "usd",
                priceId: "cg-second",
                price: "2",
                fiatDayChange: 2,
                coingeckoPriceId: "cg-second"
            )
        ]
        let piPrices = [
            PriceData(
                currencyId: "usd",
                priceId: "pi-first",
                price: "10",
                fiatDayChange: 10,
                coingeckoPriceId: "cg-first"
            )
        ]

        let merged = PriceDataSource.mergeSoraPrices(
            coingeckoPrices: coingeckoPrices,
            soraSubqueryPrices: piPrices,
            chainAssets: [firstAsset, secondAsset]
        )

        XCTAssertEqual(
            merged.first { $0.priceId == "pi-first" },
            piPrices[0]
        )
        XCTAssertEqual(
            merged.first { $0.priceId == "pi-second" }?.price,
            "2"
        )
        XCTAssertEqual(merged.filter { $0.priceId == "pi-first" }.count, 1)
        XCTAssertEqual(merged.filter { $0.priceId == "pi-second" }.count, 1)
    }

    func testUSDPlusAnotherFiatStillFetchesPI() {
        XCTAssertTrue(
            PriceDataSource.shouldFetchSoraPrices(
                for: [.defaultCurrency(), .euro()]
            )
        )
        XCTAssertFalse(PriceDataSource.shouldFetchSoraPrices(for: [.euro()]))
    }

    func testPIOutagePreservesPersistedPriceWithoutCoinGeckoFallback() throws {
        let priceId = "pi-only-price-id"
        let chainAsset = makeChainAsset(
            priceId: priceId,
            hasCoingeckoPriceId: false
        )
        let persistedPrice = PriceData(
            currencyId: "usd",
            priceId: priceId,
            price: "4.25",
            fiatDayChange: 0.5,
            coingeckoPriceId: nil
        )
        let source = PriceDataSource(
            currencies: [.defaultCurrency()],
            chainAssets: [chainAsset],
            coingeckoOperationFactory: StaticCoingeckoPriceFactory(prices: []),
            soraOperationFactory: FailingSoraPriceFetcher(),
            priceCacheReader: StaticPriceDataCacheReader(prices: [persistedPrice])
        )

        let operation = source.fetchOperation()
        OperationQueue().addOperations(operation.allOperations, waitUntilFinished: true)
        let prices = try XCTUnwrap(
            operation.targetOperation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )

        XCTAssertEqual(prices, [persistedPrice])
    }

    func testCoinGeckoFailurePreservesCachedPricesAndPublishesPI() throws {
        let piPriceId = "pi-price-id"
        let coingeckoPriceId = "coingecko-price-id"
        let invalidCachedPriceId = "invalid-cached-price-id"
        let piAsset = makeChainAsset(
            priceId: piPriceId,
            hasCoingeckoPriceId: false
        )
        let coingeckoAsset = makeChainAsset(
            priceId: coingeckoPriceId,
            providerType: .coingecko
        )
        let invalidCachedAsset = makeChainAsset(
            priceId: invalidCachedPriceId,
            hasCoingeckoPriceId: false
        )
        let persistedCoingeckoPrice = PriceData(
            currencyId: "usd",
            priceId: coingeckoPriceId,
            price: "3.5",
            fiatDayChange: 0.25,
            coingeckoPriceId: coingeckoPriceId
        )
        let freshPIPrice = PriceData(
            currencyId: "usd",
            priceId: piPriceId,
            price: "8.75",
            fiatDayChange: 1.5,
            coingeckoPriceId: nil
        )
        let invalidCachedPrice = PriceData(
            currencyId: "usd",
            priceId: invalidCachedPriceId,
            price: "0",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )
        let source = PriceDataSource(
            currencies: [.defaultCurrency()],
            chainAssets: [piAsset, coingeckoAsset, invalidCachedAsset],
            coingeckoOperationFactory: FailingCoingeckoPriceFactory(),
            soraOperationFactory: StaticSoraPriceFetcher(prices: [freshPIPrice]),
            priceCacheReader: StaticPriceDataCacheReader(
                prices: [persistedCoingeckoPrice, invalidCachedPrice]
            )
        )

        let operation = source.fetchOperation()
        OperationQueue().addOperations(operation.allOperations, waitUntilFinished: true)
        let prices = try XCTUnwrap(
            operation.targetOperation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )
        )

        XCTAssertEqual(
            Set(prices.map(\.priceId)),
            Set([coingeckoPriceId, piPriceId])
        )
        XCTAssertEqual(
            prices.first { $0.priceId == coingeckoPriceId },
            persistedCoingeckoPrice
        )
        XCTAssertEqual(prices.first { $0.priceId == piPriceId }, freshPIPrice)
        XCTAssertNil(prices.first { $0.priceId == invalidCachedPriceId })
    }

    func testPriceProviderFactoryKeepsOnePersistentWriterAcrossContextUpdates() {
        let factory = PriceProviderFactory()
        let firstProvider = factory.getPricesProvider(
            currencies: [.defaultCurrency()],
            chainAssets: [makeChainAsset(priceId: "first")]
        )
        let secondProvider = factory.getPricesProvider(
            currencies: [.defaultCurrency(), .euro()],
            chainAssets: [makeChainAsset(priceId: "second")]
        )

        XCTAssertTrue(firstProvider === secondProvider)
    }

    func testContextUpdateDuringActiveFetchRequiresAndCompletesFollowUp() throws {
        let firstAsset = makeChainAsset(priceId: "first")
        let secondAsset = makeChainAsset(priceId: "second")
        let fetcher = DelayedRecordingSoraPriceFetcher()
        let source = PriceDataSource(
            currencies: [.defaultCurrency()],
            chainAssets: [firstAsset],
            coingeckoOperationFactory: StaticCoingeckoPriceFactory(prices: []),
            soraOperationFactory: fetcher,
            priceCacheReader: StaticPriceDataCacheReader(prices: [])
        )
        let queue = OperationQueue()

        let firstFetch = source.fetchOperation()
        queue.addOperations(firstFetch.allOperations, waitUntilFinished: false)
        XCTAssertTrue(fetcher.waitUntilFirstFetchStarts())

        source.update(
            currencies: [.defaultCurrency(), .euro()],
            chainAssets: [firstAsset, secondAsset]
        )
        XCTAssertFalse(source.needsFollowUpFetch)

        fetcher.finishFirstFetch()
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(source.needsFollowUpFetch)

        let secondFetch = source.fetchOperation()
        queue.addOperations(secondFetch.allOperations, waitUntilFinished: true)

        XCTAssertFalse(source.needsFollowUpFetch)
        XCTAssertEqual(fetcher.requestedPriceIds, [["first"], ["first", "second"]])
    }

    func testSubscriberCompletesLatestContextWithOneCoalescingWriter() {
        let provider = RecordingSingleValueProvider()
        let factory = RecordingPriceProviderFactory(provider: provider)
        let subscriber = PriceLocalStorageSubscriberImpl(
            priceLocalSubscriber: factory,
            startAutomatically: false
        )
        let listener = RecordingPriceListener()
        let firstAsset = makeChainAsset(priceId: "first")
        let secondAsset = makeChainAsset(priceId: "second")

        let firstProvider = subscriber.subscribeToPrices(
            for: [firstAsset],
            currencies: [.defaultCurrency()],
            listener: listener
        )
        let secondProvider = subscriber.subscribeToPrices(
            for: [firstAsset, secondAsset],
            currencies: [.defaultCurrency(), .euro()],
            listener: listener
        )

        XCTAssertTrue(firstProvider === secondProvider)
        XCTAssertEqual(factory.createCount, 1)
        XCTAssertEqual(factory.updateCount, 1)
        XCTAssertEqual(provider.refreshAttemptCount, 2)
        XCTAssertEqual(provider.acceptedRefreshCount, 1)

        factory.needsFollowUpFetch = true
        provider.completeRefreshWithoutChanges()

        XCTAssertEqual(provider.refreshAttemptCount, 3)
        XCTAssertEqual(provider.acceptedRefreshCount, 2)

        factory.needsFollowUpFetch = false
        provider.completeRefreshWithoutChanges()

        XCTAssertEqual(provider.refreshAttemptCount, 3)
        XCTAssertEqual(provider.acceptedRefreshCount, 2)
    }

    func testSubscriberRejectsInvalidPersistedPricesBeforeCacheAndUI() {
        let provider = RecordingSingleValueProvider()
        let factory = RecordingPriceProviderFactory(provider: provider)
        let subscriber = PriceLocalStorageSubscriberImpl(
            priceLocalSubscriber: factory,
            startAutomatically: false
        )
        let listener = RecordingPriceListener()
        let validAsset = makeChainAsset(priceId: "valid-cached")
        let zeroAsset = makeChainAsset(priceId: "zero-cached")
        let malformedAsset = makeChainAsset(priceId: "malformed-cached")
        let validPrice = PriceData(
            currencyId: "usd",
            priceId: "valid-cached",
            price: "1.25",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )
        let zeroPrice = PriceData(
            currencyId: "usd",
            priceId: "zero-cached",
            price: "0",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )
        let malformedPrice = PriceData(
            currencyId: "usd",
            priceId: "malformed-cached",
            price: "1abc",
            fiatDayChange: nil,
            coingeckoPriceId: nil
        )

        _ = subscriber.subscribeToPrices(
            for: [validAsset, zeroAsset, malformedAsset],
            currencies: [.defaultCurrency()],
            listener: listener
        )
        provider.completeRefresh(
            with: [validPrice, zeroPrice, malformedPrice]
        )

        XCTAssertEqual(listener.receivedPriceIds, [["valid-cached"]])
        XCTAssertEqual(
            validAsset.asset.getPrice(for: .defaultCurrency()),
            validPrice
        )
        XCTAssertNil(zeroAsset.asset.getPrice(for: .defaultCurrency()))
        XCTAssertNil(malformedAsset.asset.getPrice(for: .defaultCurrency()))
    }

    private func makeFetcher() -> SoraSubqueryPriceFetcherDefault {
        SoraSubqueryPriceFetcherDefault(endpoint: piEndpoint, session: makeSession())
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SoraPriceURLProtocolMock.self]
        return URLSession(configuration: configuration)
    }

    private func makeChainAsset(
        priceId: String,
        currencyId: String? = nil,
        providerType: PriceProviderType = .sorasubquery,
        coingeckoPriceId: String? = nil,
        hasCoingeckoPriceId: Bool = true
    ) -> ChainAsset {
        let asset = AssetModel(
            id: "local-\(priceId)",
            name: "Synthetic asset",
            symbol: "SYN",
            precision: 18,
            currencyId: currencyId ?? priceId,
            isUtility: false,
            isNative: false,
            priceProvider: PriceProvider(type: providerType, id: priceId, precision: nil),
            coingeckoPriceId: hasCoingeckoPriceId
                ? coingeckoPriceId ?? "coingecko-\(priceId)"
                : nil
        )
        let history = ChainModel.BlockExplorer(type: "subquery", url: staleRegistryEndpoint)
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: "synthetic-sora-chain",
            paraId: nil,
            name: "SORA Mainnet",
            assets: [asset],
            xcm: nil,
            nodes: [],
            addressPrefix: 69,
            icon: nil,
            externalApi: ChainModel.ExternalApiSet(history: history, pricing: history),
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func execute(_ operation: BaseOperation<[PriceData]>) throws -> [PriceData] {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
    }

    private func requestBody(_ request: URLRequest) throws -> CapturedPriceRequest {
        let data = try requestData(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let operationName = try XCTUnwrap(json["operationName"] as? String)
        let query = try XCTUnwrap(json["query"] as? String)
        let variables = try XCTUnwrap(json["variables"] as? [String: Any])
        let first = try XCTUnwrap(variables["first"] as? Int)
        let ids = try XCTUnwrap(variables["ids"] as? [String])
        let after = variables["after"] as? String

        return CapturedPriceRequest(
            operationName: operationName,
            query: query,
            first: first,
            after: after,
            ids: ids
        )
    }

    private func requestData(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else if count == 0 {
                return data
            } else {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
        }
    }

    private func response(
        nodes: [[String: Any]],
        hasNextPage: Bool,
        endCursor: String?
    ) throws -> (HTTPURLResponse, Data) {
        let pageInfo: [String: Any] = [
            "hasNextPage": hasNextPage,
            "endCursor": endCursor ?? NSNull()
        ]
        let payload: [String: Any] = [
            "data": [
                "entities": [
                    "nodes": nodes,
                    "pageInfo": pageInfo
                ]
            ]
        ]
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: piEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )

        return (response, try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
    }
}

private struct CapturedPriceRequest {
    let operationName: String
    let query: String
    let first: Int
    let after: String?
    let ids: [String]
}

private final class RequestRecorder {
    private let lock = NSLock()
    private var capturedValues: [CapturedPriceRequest] = []

    var values: [CapturedPriceRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedValues
    }

    @discardableResult
    func append(_ value: CapturedPriceRequest) -> Int {
        lock.lock()
        defer { lock.unlock() }
        capturedValues.append(value)
        return capturedValues.count - 1
    }
}

private struct StaticCoingeckoPriceFactory: CoingeckoOperationFactoryProtocol {
    let prices: [PriceData]

    func fetchPriceOperation(
        for _: [String],
        currencies _: [Currency]
    ) -> BaseOperation<[PriceData]> {
        ClosureOperation { prices }
    }
}

private struct FailingCoingeckoPriceFactory: CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for _: [String],
        currencies _: [Currency]
    ) -> BaseOperation<[PriceData]> {
        ClosureOperation {
            throw NSError(domain: "FailingCoingeckoPriceFactory", code: 1)
        }
    }
}

private struct FailingSoraPriceFetcher: SoraSubqueryPriceFetcher {
    func fetchPriceOperation(
        for _: [ChainAsset]
    ) -> BaseOperation<[PriceData]> {
        ClosureOperation {
            throw NSError(domain: "FailingSoraPriceFetcher", code: 1)
        }
    }
}

private struct StaticSoraPriceFetcher: SoraSubqueryPriceFetcher {
    let prices: [PriceData]

    func fetchPriceOperation(
        for _: [ChainAsset]
    ) -> BaseOperation<[PriceData]> {
        ClosureOperation { prices }
    }
}

private struct StaticPriceDataCacheReader: PriceDataCacheReading {
    let prices: [PriceData]

    func fetchPricesOperation() -> CompoundOperationWrapper<[PriceData]> {
        CompoundOperationWrapper(
            targetOperation: ClosureOperation { prices }
        )
    }
}

private final class DelayedRecordingSoraPriceFetcher: SoraSubqueryPriceFetcher {
    private let lock = NSLock()
    private let firstFetchStarted = DispatchSemaphore(value: 0)
    private let finishFirstFetchSemaphore = DispatchSemaphore(value: 0)
    private var capturedPriceIds: [[String]] = []

    var requestedPriceIds: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return capturedPriceIds
    }

    func fetchPriceOperation(
        for chainAssets: [ChainAsset]
    ) -> BaseOperation<[PriceData]> {
        lock.lock()
        let requestIndex = capturedPriceIds.count
        capturedPriceIds.append(chainAssets.compactMap { $0.asset.priceId })
        lock.unlock()

        return ClosureOperation { [weak self] in
            guard let self else {
                throw PriceDataSourceError.memoryError
            }

            if requestIndex == 0 {
                self.firstFetchStarted.signal()
                guard self.finishFirstFetchSemaphore.wait(timeout: .now() + 5) == .success else {
                    throw NSError(domain: "DelayedRecordingSoraPriceFetcher", code: 1)
                }
            }

            return []
        }
    }

    func waitUntilFirstFetchStarts() -> Bool {
        firstFetchStarted.wait(timeout: .now() + 5) == .success
    }

    func finishFirstFetch() {
        finishFirstFetchSemaphore.signal()
    }
}

private final class RecordingPriceProviderFactory: PriceProviderFactoryProtocol {
    private let provider: AnySingleValueProvider<[PriceData]>
    private(set) var createCount = 0
    private(set) var updateCount = 0
    var needsFollowUpFetch = false

    init(provider: RecordingSingleValueProvider) {
        self.provider = AnySingleValueProvider(provider)
    }

    func getPricesProvider(
        currencies _: [Currency]?,
        chainAssets _: [ChainAsset]
    ) -> AnySingleValueProvider<[PriceData]> {
        createCount += 1
        return provider
    }

    func updatePricesProvider(
        currencies _: [Currency]?,
        chainAssets _: [ChainAsset]
    ) {
        updateCount += 1
    }

    func pricesProviderNeedsFollowUpFetch() -> Bool {
        needsFollowUpFetch
    }
}

private final class RecordingSingleValueProvider: SingleValueProviderProtocol {
    typealias Model = [PriceData]

    let executionQueue = OperationQueue()
    private(set) var refreshAttemptCount = 0
    private(set) var acceptedRefreshCount = 0
    private var isRefreshInFlight = false
    private var updateClosure: (([DataProviderChange<[PriceData]>]) -> Void)?

    func fetch(
        with completionBlock: ((Result<[PriceData]?, Error>?) -> Void)?
    ) -> CompoundOperationWrapper<[PriceData]?> {
        let wrapper = CompoundOperationWrapper<[PriceData]?>(
            targetOperation: ClosureOperation { [] }
        )
        completionBlock?(.success([]))
        return wrapper
    }

    func addObserver(
        _: AnyObject,
        deliverOn _: DispatchQueue?,
        executing: @escaping ([DataProviderChange<[PriceData]>]) -> Void,
        failing _: @escaping (Error) -> Void,
        options _: DataProviderObserverOptions
    ) {
        updateClosure = executing
    }

    func removeObserver(_: AnyObject) {}

    func refresh() {
        refreshAttemptCount += 1
        guard !isRefreshInFlight else {
            return
        }

        isRefreshInFlight = true
        acceptedRefreshCount += 1
    }

    func completeRefreshWithoutChanges() {
        precondition(isRefreshInFlight)
        isRefreshInFlight = false
        updateClosure?([])
    }

    func completeRefresh(with prices: [PriceData]) {
        precondition(isRefreshInFlight)
        isRefreshInFlight = false
        updateClosure?([.insert(newItem: prices)])
    }
}

private final class RecordingPriceListener: PriceLocalSubscriptionHandler {
    private(set) var receivedPriceIds: [[String]] = []

    func handlePrices(
        result: Result<[PriceData], Error>,
        for _: [ChainAsset]
    ) {
        guard case let .success(prices) = result else {
            return
        }

        receivedPriceIds.append(prices.map(\.priceId))
    }
}

private final class SoraPriceURLProtocolMock: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: NSError(domain: "SoraPriceURLProtocolMock", code: 1)
            )
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
