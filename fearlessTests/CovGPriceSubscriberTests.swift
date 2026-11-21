import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovGPriceSubscriberTests: XCTestCase {
    func testSingleAssetSubscriptionFiltersPricesAndForwardsProviderFailures() throws {
        let provider = CovGPriceProvider()
        let factory = CovGPriceFactory(provider: provider)
        let subscriber = PriceLocalStorageSubscriberImpl(priceLocalSubscriber: factory, startAutomatically: false)
        let listener = CovGPriceListener()
        let unit = chainAsset(priceId: "cov-g-unit")
        let returned = subscriber.subscribeToPrice(for: unit, currencies: [.defaultCurrency()], listener: listener)
        XCTAssertEqual(factory.createCount, 1)
        XCTAssertEqual(provider.refreshCount, 1)
        XCTAssertTrue(provider.isObserved)

        provider.deliver([.insert(newItem: [
            price("cov-g-unit", "2.5"), price("cov-g-other", "3"), price("cov-g-unit", "-1"), price("cov-g-unit", "4", currency: "eur"),
        ])])
        XCTAssertEqual(listener.successes, [["cov-g-unit"]])
        XCTAssertEqual(listener.assets.last?.map(\.chainAssetId), [unit.chainAssetId])

        provider.fail(NSError(domain: "CovG.price", code: 66))
        XCTAssertEqual(listener.failures, [66])

        let again = subscriber.subscribeToPrice(for: unit, currencies: [.defaultCurrency()], listener: listener)
        XCTAssertEqual(factory.createCount, 1)
        XCTAssertEqual(factory.updateCount, 0)
        withExtendedLifetime([returned, again]) {}
    }

    func testMultipleAssetSubscriptionUpdatesProviderContextAndDropsReleasedListeners() throws {
        let provider = CovGPriceProvider()
        let factory = CovGPriceFactory(provider: provider)
        let subscriber = PriceLocalStorageSubscriberImpl(priceLocalSubscriber: factory, startAutomatically: false)
        let first = chainAsset(priceId: "cov-g-first")
        let second = chainAsset(priceId: "cov-g-second")
        let listener = CovGPriceListener()
        var transient: CovGPriceListener? = CovGPriceListener()
        _ = subscriber.subscribeToPrices(for: [first], currencies: [.defaultCurrency()], listener: listener)
        _ = subscriber.subscribeToPrices(for: [first, second], currencies: [.defaultCurrency()], listener: try XCTUnwrap(transient))
        XCTAssertEqual(factory.createCount, 1)
        XCTAssertEqual(factory.updateCount, 1)
        XCTAssertEqual(provider.refreshCount, 2)

        transient = nil
        provider.deliver([.update(newItem: [price("cov-g-first", "1"), price("cov-g-second", "2")])])
        XCTAssertEqual(listener.successes, [["cov-g-first"]])

        factory.needsFollowUpFetch = true
        provider.deliver([])
        XCTAssertEqual(provider.refreshCount, 3)
        XCTAssertEqual(listener.successes.count, 1)
    }

    func testDefaultCurrencyOverloadsUseSelectedWalletCurrencyWhenAvailable() throws {
        let provider = CovGPriceProvider()
        let factory = CovGPriceFactory(provider: provider)
        let subscriber = PriceLocalStorageSubscriberImpl(priceLocalSubscriber: factory, startAutomatically: false)
        let listener = CovGPriceListener()
        let unit = chainAsset(priceId: "cov-g-default")
        let single = subscriber.subscribeToPrice(for: unit, listener: listener)
        let multiple = subscriber.subscribeToPrices(for: [unit], listener: listener)
        XCTAssertTrue(single === multiple)
        XCTAssertEqual(factory.createCount, 1)
        provider.deliver([.insert(newItem: [price("cov-g-default", "1", currency: "usd")])])
        if let currency = SelectedWalletSettings.shared.value?.selectedCurrency {
            XCTAssertEqual(listener.successes.last, currency.id == "usd" ? ["cov-g-default"] : [])
        } else {
            XCTAssertTrue(listener.successes.isEmpty)
        }
    }

    func testChainSyncWithoutChangesDoesNotTouchProvider() throws {
        let provider = CovGPriceProvider()
        let factory = CovGPriceFactory(provider: provider)
        let subscriber = PriceLocalStorageSubscriberImpl(priceLocalSubscriber: factory, startAutomatically: false)
        subscriber.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [], removedChains: []))
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(factory.createCount, 0)
        XCTAssertEqual(provider.refreshCount, 0)
    }

    private func price(_ id: String, _ value: String, currency: String = "usd") -> PriceData {
        PriceData(currencyId: currency, priceId: id, price: value, fiatDayChange: nil, coingeckoPriceId: nil)
    }

    private func chainAsset(priceId: String) -> ChainAsset {
        let asset = AssetModel(
            id: "asset-\(priceId)", name: "Token", symbol: "TKN", precision: 12, isUtility: true, isNative: true,
            priceProvider: PriceProvider(type: .coingecko, id: priceId, precision: nil), coingeckoPriceId: priceId
        )
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "chain-\(priceId)", paraId: nil, name: "Coverage chain", assets: [asset], xcm: nil,
            nodes: [], addressPrefix: 42, icon: nil, options: [], externalApi: nil, iosMinAppVersion: nil, identityChain: nil
        )
        return ChainAsset(chain: chain, asset: asset)
    }
}

final class CovGPriceListener: PriceLocalSubscriptionHandler {
    private(set) var successes: [[String]] = []
    private(set) var failures: [Int] = []
    private(set) var assets: [[ChainAsset]] = []

    func handlePrices(result: Result<[PriceData], Error>, for chainAssets: [ChainAsset]) {
        assets.append(chainAssets)
        switch result {
        case let .success(prices):
            successes.append(prices.map(\.priceId))
        case let .failure(error):
            failures.append((error as NSError).code)
        }
    }
}

final class CovGPriceFactory: PriceProviderFactoryProtocol {
    private let provider: AnySingleValueProvider<[PriceData]>
    private(set) var createCount = 0
    private(set) var updateCount = 0
    var needsFollowUpFetch = false

    init(provider: CovGPriceProvider) {
        self.provider = AnySingleValueProvider(provider)
    }

    func getPricesProvider(currencies _: [Currency]?, chainAssets _: [ChainAsset]) -> AnySingleValueProvider<[PriceData]> {
        createCount += 1
        return provider
    }

    func updatePricesProvider(currencies _: [Currency]?, chainAssets _: [ChainAsset]) {
        updateCount += 1
    }

    func pricesProviderNeedsFollowUpFetch() -> Bool {
        needsFollowUpFetch
    }
}

final class CovGPriceProvider: SingleValueProviderProtocol {
    typealias Model = [PriceData]

    let executionQueue = OperationQueue()
    private(set) var refreshCount = 0
    private var update: (([DataProviderChange<[PriceData]>]) -> Void)?
    private var failure: ((Error) -> Void)?

    var isObserved: Bool {
        update != nil
    }

    func fetch(with completionBlock: ((Result<[PriceData]?, Error>?) -> Void)?) -> CompoundOperationWrapper<[PriceData]?> {
        completionBlock?(.success([]))
        return CompoundOperationWrapper(targetOperation: ClosureOperation { [] })
    }

    func addObserver(
        _: AnyObject, deliverOn _: DispatchQueue?, executing: @escaping ([DataProviderChange<[PriceData]>]) -> Void,
        failing: @escaping (Error) -> Void, options _: DataProviderObserverOptions
    ) {
        update = executing
        failure = failing
    }

    func removeObserver(_: AnyObject) {
        update = nil
        failure = nil
    }

    func refresh() {
        refreshCount += 1
    }

    func deliver(_ changes: [DataProviderChange<[PriceData]>]) {
        update?(changes)
    }

    func fail(_ error: Error) {
        failure?(error)
    }
}
