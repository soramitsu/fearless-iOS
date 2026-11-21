import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovFMiscPricesTests: XCTestCase {
    func testSetupSubscribesToEveryChainAssetAndUniqueWalletCurrency() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let euroWallet = AccountGenerator.generateMetaAccount().replacingCurrency(.euro())
        let fixture = CovFMiscPricesFixture(chains: [covFMiscChain(id: "p1", assetIds: ["a", "b"])], wallets: [wallet, euroWallet, wallet])
        fixture.service.setup()
        try covFMiscEventually { fixture.subscriber.requests.count == 1 }
        let request = try XCTUnwrap(fixture.subscriber.requests.first)
        XCTAssertEqual(Set(request.assets.map(\.asset.id)), ["a", "b"])
        XCTAssertEqual(Set(request.currencies.map(\.id)), ["usd", "eur"])
        XCTAssertTrue(request.onMain)

        fixture.service.updatePrices()
        XCTAssertEqual(fixture.subscriber.providers.first?.refreshes, 1)
    }

    func testChainEventsAddOnlyNewAssets() throws {
        let fixture = CovFMiscPricesFixture(chains: [], wallets: [])
        let first = covFMiscChain(id: "p2", assetIds: ["x"])
        fixture.service.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [first], removedChains: []))
        XCTAssertEqual(fixture.subscriber.requests.last.map { $0.assets.map(\.asset.id) }, ["x"])
        let second = covFMiscChain(id: "p3", assetIds: ["y"])
        fixture.service.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [first, second]))
        XCTAssertEqual(fixture.subscriber.requests.count, 2)
        XCTAssertEqual(fixture.subscriber.requests.last.map { Set($0.assets.map(\.asset.id)) }, ["x", "y"])
        fixture.service.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [second]))
        XCTAssertEqual(fixture.subscriber.requests.count, 2)
    }

    func testBackgroundEventIsAppliedOnMain() throws {
        let fixture = CovFMiscPricesFixture(chains: [], wallets: [])
        let chain = covFMiscChain(id: "p4", assetIds: ["z"])
        DispatchQueue.global().async {
            fixture.service.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [chain]))
        }
        try covFMiscEventually { fixture.subscriber.requests.count == 1 }
        XCTAssertEqual(fixture.subscriber.requests.first?.onMain, true)
    }

    func testPriceResultsUpdateExactCacheAndNotifyOnlyOnSuccess() {
        let fixture = CovFMiscPricesFixture(chains: [], wallets: [])
        let observer = CovFMiscPricesObserver()
        fixture.events.add(observer: observer, dispatchIn: .main)
        let priceId = "covf-misc-\(UUID().uuidString)"
        let notified = expectation(description: "prices updated")
        observer.onPrices = { notified.fulfill() }
        let asset = CovFFixtures.asset()
        fixture.service.handlePrice(result: .success(nil), chainAsset: asset)
        fixture.service.handlePrices(result: .failure(NSError(domain: "prices", code: 1)), for: [asset])
        fixture.service.handlePrices(
            result: .success([PriceData(currencyId: "usd", priceId: priceId, price: "2.5", fiatDayChange: 1, coingeckoPriceId: nil)]),
            for: [asset]
        )
        wait(for: [notified], timeout: 5)
        XCTAssertEqual(observer.count, 1)
        XCTAssertEqual(ExactAssetPriceCache.shared.price(priceId: priceId, currencyId: "usd")?.price, "2.5")
    }

    func testSharedServiceIsTheDefaultImplementation() {
        XCTAssertTrue(PricesService.shared is PricesService)
    }
}

private final class CovFMiscPricesFixture {
    let subscriber = CovFMiscPriceSubscriber()
    let events = EventCenter()
    let service: PricesService

    init(chains: [ChainModel], wallets: [fearless.MetaAccountModel]) {
        service = PricesService(
            chainRepository: AnyDataProviderRepository(CovFRepository<ChainModel>(chains)),
            walletRepository: AnyDataProviderRepository(CovFRepository<fearless.MetaAccountModel>(wallets)),
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            eventCenter: events,
            priceLocalSubscriber: subscriber
        )
    }
}

private final class CovFMiscPricesObserver: EventVisitorProtocol {
    var count = 0
    var onPrices: (() -> Void)?
    func processPricesUpdated() {
        count += 1
        onPrices?()
    }
}

final class CovFMiscPriceProvider: SingleValueProviderProtocol {
    typealias Model = [PriceData]
    let executionQueue = OperationQueue()
    private(set) var refreshes = 0

    func fetch(with _: ((Result<Model?, Error>?) -> Void)?) -> CompoundOperationWrapper<Model?> {
        CompoundOperationWrapper(targetOperation: CovFFixtures.result(nil))
    }

    func addObserver(
        _: AnyObject,
        deliverOn _: DispatchQueue?,
        executing _: @escaping ([DataProviderChange<Model>]) -> Void,
        failing _: @escaping (Error) -> Void,
        options _: DataProviderObserverOptions
    ) {}

    func removeObserver(_: AnyObject) {}
    func refresh() { refreshes += 1 }
}

final class CovFMiscPriceSubscriber: PriceLocalStorageSubscriber {
    struct CovFMiscRequest {
        let assets: [ChainAsset]
        let currencies: [Currency]
        let onMain: Bool
    }

    private let lock = NSLock()
    private var storedRequests: [CovFMiscRequest] = []
    private(set) var providers: [CovFMiscPriceProvider] = []

    var requests: [CovFMiscRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    func subscribeToPrice(for chainAsset: ChainAsset, listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: [chainAsset], currencies: nil, listener: listener)
    }

    func subscribeToPrice(
        for chainAsset: ChainAsset, currencies: [Currency]?, listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: [chainAsset], currencies: currencies, listener: listener)
    }

    func subscribeToPrices(for chainAssets: [ChainAsset], listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: chainAssets, currencies: nil, listener: listener)
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset], currencies: [Currency]?, listener _: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        let provider = CovFMiscPriceProvider()
        lock.lock()
        storedRequests.append(CovFMiscRequest(assets: chainAssets, currencies: currencies ?? [], onMain: Thread.isMainThread))
        providers.append(provider)
        lock.unlock()
        return AnySingleValueProvider(provider)
    }
}
