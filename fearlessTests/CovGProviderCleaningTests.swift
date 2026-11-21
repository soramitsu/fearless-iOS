import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovGProviderCleaningTests: XCTestCase {
    func testClearingProvidersRemovesTheObserverAndDropsTheReference() {
        let cleaner = CovGCleaner()
        let priceProvider = CovGPriceProvider()
        var single: AnySingleValueProvider<[PriceData]>? = AnySingleValueProvider(priceProvider)
        single?.addObserver(
            cleaner, deliverOn: nil, executing: { _ in }, failing: { _ in },
            options: DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
        )
        XCTAssertTrue(priceProvider.isObserved)
        cleaner.clear(singleValueProvider: &single)
        XCTAssertNil(single)
        XCTAssertFalse(priceProvider.isObserved)

        let observable = CovGStreamObservable<AccountInfoStorageWrapper>()
        var streamable: StreamableProvider<AccountInfoStorageWrapper>? = observable.provider(result: .success([]))
        streamable?.addObserver(
            cleaner, deliverOn: .main, executing: { _ in }, failing: { _ in }, options: StreamableProviderObserverOptions()
        )
        waitUntil { observable.isObserved }
        cleaner.clear(streamableProvider: &streamable)
        XCTAssertNil(streamable)
        waitUntil { !observable.isObserved }

        var data: AnyDataProvider<DecodedU32>?
        cleaner.clear(dataProvider: &data)
        XCTAssertNil(data)
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate())
    }
}

private final class CovGCleaner: AnyProviderAutoCleaning {}
