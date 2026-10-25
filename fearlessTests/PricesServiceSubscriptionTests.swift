import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class PricesServiceSubscriptionTests: XCTestCase {
    func testBackgroundEventDoesNotBlockMainSubscriptionDelivery() {
        let subscriber = RecordingPriceSubscriber()
        subscriber.deliverOnMain = true
        let service = makeService(subscriber)
        let wallet = AccountGenerator.generateMetaAccount()
        let delivered = expectation(description: "both Main subscriptions delivered")
        delivered.expectedFulfillmentCount = 2
        subscriber.beforeReturn = { _ in delivered.fulfill() }
        let backgroundReturned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            service.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet))
            backgroundReturned.signal()
        }
        // Keep Main occupied while background setup/event work requests a subscription.
        // The service must enqueue its transition, not hold a lock while waiting for Main.
        XCTAssertEqual(backgroundReturned.wait(timeout: .now() + 0.2), .success)
        service
            .processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet.replacingCurrency(.euro())))
        wait(for: [delivered], timeout: 5)
        XCTAssertEqual(subscriber.requests.map { Set($0.map(\.id)) }, [Set(["eur"]), Set(["usd", "eur"])])
        XCTAssertTrue(subscriber.deliveryThreads.allSatisfy { $0 })
    }

    func testSynchronousSubscriptionCallbackCannotOverwriteNewerCurrencyState() {
        let subscriber = RecordingPriceSubscriber()
        let service = makeService(subscriber)
        let wallet = AccountGenerator.generateMetaAccount()
        subscriber.beforeReturn = { currencies in
            if Set(currencies.map(\.id)) == Set(["usd"]) {
                service
                    .processMetaAccountChanged(event: MetaAccountModelChangedEvent(
                        account: wallet
                            .replacingCurrency(.euro())
                    ))
            }
        }
        service.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet))
        XCTAssertEqual(subscriber.requests.map { Set($0.map(\.id)) }, [Set(["usd"]), Set(["usd", "eur"])])
        let count = subscriber.requests.count
        service
            .processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet.replacingCurrency(.euro())))
        XCTAssertEqual(subscriber.requests.count, count)
    }

    func testNewWalletCurrencyDoesNotRemovePreviouslyRequestedCurrency() {
        let subscriber = RecordingPriceSubscriber()
        let service = makeService(subscriber)
        let wallet = AccountGenerator.generateMetaAccount()
        service.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet))
        service
            .processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet.replacingCurrency(.euro())))
        XCTAssertEqual(subscriber.requests.map { Set($0.map(\.id)) }, [Set(["usd"]), Set(["usd", "eur"])])
        let count = subscriber.requests.count
        service.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet))
        XCTAssertEqual(subscriber.requests.count, count)
    }

    func testFirstSelectedWalletStartsCurrencySubscription() {
        let subscriber = RecordingPriceSubscriber()
        let service = makeService(subscriber)
        service
            .processSelectedAccountChanged(event: SelectedAccountChanged(
                account: AccountGenerator
                    .generateMetaAccount()
            ))
        XCTAssertEqual(subscriber.requests.map { Set($0.map(\.id)) }, [Set(["usd"])])
    }

    private func makeService(_ subscriber: RecordingPriceSubscriber) -> PricesService {
        let chains = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let wallets = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        return PricesService(
            chainRepository: AnyDataProviderRepository(chains), walletRepository: AnyDataProviderRepository(wallets),
            operationQueue: OperationQueue(), logger: Logger.shared, eventCenter: EventCenter(),
            priceLocalSubscriber: subscriber
        )
    }
}

private final class RecordingPriceSubscriber: PriceLocalStorageSubscriber {
    private let lock = NSLock()
    private var recordedRequests: [[Currency]] = []
    var beforeReturn: (([Currency]) -> Void)?
    var deliverOnMain = false
    private(set) var deliveryThreads: [Bool] = []
    var requests: [[Currency]] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func subscribeToPrice(
        for chainAsset: ChainAsset,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: [chainAsset], currencies: nil, listener: listener)
    }

    func subscribeToPrice(
        for chainAsset: ChainAsset,
        currencies: [Currency]?,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: [chainAsset], currencies: currencies, listener: listener)
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset],
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: chainAssets, currencies: nil, listener: listener)
    }

    func subscribeToPrices(
        for _: [ChainAsset],
        currencies: [Currency]?,
        listener _: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        if deliverOnMain, !Thread.isMainThread {
            let delivered = DispatchSemaphore(value: 0)
            DispatchQueue.main.async {
                self.record(currencies ?? [])
                delivered.signal()
            }
            // Bounded equivalent of the production subscriber's main.sync contract:
            // fail rather than hanging the test host on the historical lock inversion.
            XCTAssertEqual(delivered.wait(timeout: .now() + 0.5), .success)
        } else {
            record(currencies ?? [])
        }
        return AnySingleValueProvider(SingleValueProviderStub<[PriceData]>(item: nil))
    }

    private func record(_ currencies: [Currency]) {
        lock.lock()
        recordedRequests.append(currencies)
        deliveryThreads.append(Thread.isMainThread)
        lock.unlock()
        beforeReturn?(currencies)
    }
}
