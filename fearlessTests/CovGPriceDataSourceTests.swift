import Foundation
import RobinHood
import SSFModels
import Web3
import XCTest
@testable import fearless

final class CovGPriceDataSourceTests: XCTestCase {
    func testCacheReaderDecodesStoredPricesAndToleratesMissingOrCorruptPayloads() throws {
        let repository = InMemoryDataProviderRepository<SingleValueProviderObject>()
        let reader = PriceDataCacheReader(repository: AnyDataProviderRepository(repository), identifier: "cov-g-prices")
        XCTAssertTrue(try CovGOperationFixtures.run(reader.fetchPricesOperation()).isEmpty)
        let stored = [price("cov-g-a", "1.5"), price("cov-g-b", "2", currency: "eur")]
        let payload = try JSONEncoder().encode(stored)
        try CovGOperationFixtures.run(repository.saveOperation({ [SingleValueProviderObject(identifier: "cov-g-prices", payload: payload)] }, { [] }))
        let read = try CovGOperationFixtures.run(reader.fetchPricesOperation())
        XCTAssertEqual(read.map(\.priceId), ["cov-g-a", "cov-g-b"])
        XCTAssertEqual(read.map(\.currencyId), ["usd", "eur"])
        XCTAssertEqual(read.first?.price, "1.5")
        try CovGOperationFixtures.run(repository.saveOperation({
            [SingleValueProviderObject(identifier: "cov-g-prices", payload: Data("invalid".utf8))]
        }, { [] }))
        XCTAssertTrue(try CovGOperationFixtures.run(reader.fetchPricesOperation()).isEmpty)
    }

    func testChainlinkPricesReplaceMatchingCoingeckoPricesAndKeepItsDayChange() throws {
        let chainlinkAsset = asset(id: "link", provider: PriceProvider(type: .chainlink, id: "cov-g-feed", precision: 8), coingecko: "cov-g-link")
        let plainAsset = asset(id: "plain", provider: nil, coingecko: "cov-g-plain")
        let chain = makeChain(assets: [chainlinkAsset, plainAsset], options: [.chainlinkProvider])
        let coingecko = CovGCoingeckoStub(result: .success([
            PriceData(currencyId: "usd", priceId: "cov-g-link", price: "10", fiatDayChange: 5, coingeckoPriceId: "cov-g-link"),
            PriceData(currencyId: "usd", priceId: "cov-g-plain", price: "3", fiatDayChange: 1, coingeckoPriceId: "cov-g-plain"),
        ]))
        let chainlink = CovGChainlinkStub(
            price: PriceData(currencyId: "usd", priceId: "cov-g-feed", price: "11", fiatDayChange: nil, coingeckoPriceId: "cov-g-link")
        )
        let source = PriceDataSource(
            currencies: [.defaultCurrency()], chainAssets: chain.chainAssets, coingeckoOperationFactory: coingecko,
            chainlinkOperationFactory: chainlink, soraOperationFactory: CovGSoraPriceStub(), priceCacheReader: CovGPriceCacheStub(prices: []),
            chainRegistry: CovGHistoryRegistry()
        )
        let prices = try XCTUnwrap(CovGOperationFixtures.run(source.fetchOperation()))
        XCTAssertEqual(prices.map(\.priceId), ["cov-g-plain", "cov-g-feed"])
        XCTAssertEqual(prices.last?.price, "11")
        XCTAssertEqual(prices.last?.fiatDayChange, 5)
        XCTAssertEqual(chainlink.requested, ["link"])
        XCTAssertEqual(coingecko.requestedIds, ["cov-g-link", "cov-g-plain"])
    }

    func testCoingeckoFailureFallsBackToRelevantCachedPrices() throws {
        let plainAsset = asset(id: "plain", provider: nil, coingecko: "cov-g-cached")
        let chain = makeChain(assets: [plainAsset], options: [])
        let cache = CovGPriceCacheStub(prices: [
            price("cov-g-cached", "2"), price("cov-g-cached", "9", currency: "eur"), price("cov-g-unrelated", "1"),
        ])
        let source = PriceDataSource(
            currencies: [.defaultCurrency()], chainAssets: chain.chainAssets,
            coingeckoOperationFactory: CovGCoingeckoStub(result: .failure(NSError(domain: "CovG.coingecko", code: 67))),
            chainlinkOperationFactory: CovGChainlinkStub(price: nil), soraOperationFactory: CovGSoraPriceStub(), priceCacheReader: cache,
            chainRegistry: CovGHistoryRegistry()
        )
        let prices = try XCTUnwrap(CovGOperationFixtures.run(source.fetchOperation()))
        XCTAssertEqual(prices.map(\.priceId), ["cov-g-cached"])
        XCTAssertEqual(prices.map(\.price), ["2"])
        XCTAssertFalse(source.needsFollowUpFetch)
        source.update(currencies: [.defaultCurrency()], chainAssets: chain.chainAssets)
        XCTAssertTrue(source.needsFollowUpFetch)
    }

    func testIdentifierFollowsCurrenciesAndWalletCurrencyChanges() throws {
        let chain = makeChain(assets: [asset(id: "plain", provider: nil, coingecko: "cov-g-id")], options: [])
        let source = PriceDataSource(
            currencies: [.defaultCurrency()], chainAssets: chain.chainAssets, coingeckoOperationFactory: CovGCoingeckoStub(result: .success([])),
            chainlinkOperationFactory: CovGChainlinkStub(price: nil), soraOperationFactory: CovGSoraPriceStub(),
            priceCacheReader: CovGPriceCacheStub(prices: []), chainRegistry: CovGHistoryRegistry()
        )
        XCTAssertEqual(source.identifier, "usd")
        source.update(currencies: nil, chainAssets: chain.chainAssets)
        XCTAssertEqual(source.identifier, PriceDataSource.defaultIdentifier)
        XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation())) {
            guard case PriceDataSourceError.inputDataMissed = $0 else { return XCTFail("Wrong error \($0)") }
        }
        let account = AccountGenerator.generateMetaAccount()
        source.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: account))
        XCTAssertEqual(source.identifier, account.selectedCurrency.id)
        source.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: account))
        XCTAssertEqual(source.identifier, account.selectedCurrency.id)
        XCTAssertTrue(PriceDataSource.shouldFetchSoraPrices(for: [.defaultCurrency()]))
        XCTAssertFalse(PriceDataSource.shouldFetchSoraPrices(for: nil))
    }

    private func price(_ id: String, _ value: String, currency: String = "usd") -> PriceData {
        PriceData(currencyId: currency, priceId: id, price: value, fiatDayChange: nil, coingeckoPriceId: id)
    }

    private func asset(id: String, provider: PriceProvider?, coingecko: String) -> AssetModel {
        AssetModel(
            id: id, name: id, symbol: id.uppercased(), precision: 12, isUtility: id == "plain", isNative: false,
            priceProvider: provider, coingeckoPriceId: coingecko
        )
    }

    private func makeChain(assets: [AssetModel], options: [ChainOptions]) -> ChainModel {
        ChainModel(
            rank: nil, disabled: false, chainId: "cov-g-price-chain", paraId: nil, name: "Coverage chain", assets: Set(assets), xcm: nil,
            nodes: [], addressPrefix: 42, icon: nil, options: options, externalApi: nil, iosMinAppVersion: nil, identityChain: nil
        )
    }
}

private final class CovGCoingeckoStub: CoingeckoOperationFactoryProtocol {
    let result: Result<[PriceData], Error>
    private(set) var requestedIds: [String] = []
    init(result: Result<[PriceData], Error>) {
        self.result = result
    }

    func fetchPriceOperation(for tokenIds: [String], currencies _: [Currency]) -> BaseOperation<[PriceData]> {
        requestedIds = tokenIds
        let operation = BaseOperation<[PriceData]>()
        operation.result = result
        return operation
    }
}

private final class CovGChainlinkStub: ChainlinkOperationFactory {
    let price: PriceData?
    private(set) var requested: [String] = []
    init(price: PriceData?) {
        self.price = price
    }

    func priceCall(for chainAsset: ChainAsset, connection _: Web3.Eth?) -> BaseOperation<PriceData>? {
        requested.append(chainAsset.asset.id)
        guard let price else {
            return nil
        }
        let operation = BaseOperation<PriceData>()
        operation.result = .success(price)
        return operation
    }
}

private struct CovGSoraPriceStub: SoraSubqueryPriceFetcher {
    func fetchPriceOperation(for _: [ChainAsset]) -> BaseOperation<[PriceData]> {
        let operation = BaseOperation<[PriceData]>()
        operation.result = .success([])
        return operation
    }
}

private struct CovGPriceCacheStub: PriceDataCacheReading {
    let prices: [PriceData]
    func fetchPricesOperation() -> CompoundOperationWrapper<[PriceData]> {
        let operation = BaseOperation<[PriceData]>()
        operation.result = .success(prices)
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
