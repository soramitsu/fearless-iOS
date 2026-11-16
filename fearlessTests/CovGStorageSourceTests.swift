@testable import fearless
import Foundation
import RobinHood
import SSFRuntimeCodingService
import SSFUtils
import XCTest

final class CovGStorageSourceTests: XCTestCase {
    func testOptionalSourceMapsUpdatesDeletionAndUnknownIdentifiers() throws {
        let observable = CovGStreamObservable<ChainStorageItem>()
        let provider = observable.provider(result: .success([]))
        let trigger = CovGTriggerObserver()
        let proxy = DataProviderProxyTrigger()
        proxy.delegate = trigger
        let source = StorageProviderSource<fearless.StringScaleMapper<UInt32>>(
            itemIdentifier: "era", codingPath: .currentEra, runtimeService: CovGHistoryRuntime(),
            provider: provider, trigger: proxy, shouldUseFallback: false
        )
        waitUntil { observable.isObserved && trigger.count == 1 }
        XCTAssertNil(try CovGOperationFixtures.run(source.fetchOperation(by: "era"))?.item)
        let unknown = try CovGOperationFixtures.run(source.fetchOperation(by: "other"))
        XCTAssertEqual(unknown?.identifier, "other")
        XCTAssertNil(unknown?.item)
        let item = ChainStorageItem(identifier: "era", data: Data([42, 0, 0, 0]))
        observable.emit([.insert(newItem: item)])
        waitUntil { trigger.count == 2 }
        let value = try CovGOperationFixtures.run(source.fetchOperation(by: "era"))
        XCTAssertEqual(value?.item?.value, 42)
        let page = try CovGOperationFixtures.run(source.fetchOperation(page: 0))
        XCTAssertEqual(page.map(\.identifier), ["era"])
        XCTAssertEqual(page.first?.item?.value, 42)
        observable.emit([.delete(deletedIdentifier: "era")])
        waitUntil { trigger.count == 3 }
        XCTAssertNil(try CovGOperationFixtures.run(source.fetchOperation(page: 0)).first?.item)
    }

    func testFallbackSourceUsesStorageDefaultThenLatestValue() throws {
        let observable = CovGStreamObservable<ChainStorageItem>()
        let trigger = CovGTriggerObserver()
        let proxy = DataProviderProxyTrigger()
        proxy.delegate = trigger
        let source = try StorageProviderSource<fearless.StringScaleMapper<UInt32>>(
            itemIdentifier: "counter", codingPath: .counterForNominators,
            runtimeService: AssetHubRuntimeFixture(name: "polkadot"),
            provider: observable.provider(result: .success([])), trigger: proxy, shouldUseFallback: true
        )
        waitUntil { observable.isObserved && trigger.count == 1 }
        XCTAssertEqual(try CovGOperationFixtures.run(source.fetchOperation(by: "counter"))?.item?.value, 0)
        observable.emit([.update(newItem: ChainStorageItem(identifier: "counter", data: Data([9, 0, 0, 0])))])
        waitUntil { trigger.count == 2 }
        XCTAssertEqual(try CovGOperationFixtures.run(source.fetchOperation(page: 1)).first?.item?.value, 9)
    }

    func testProviderAndRuntimeFailuresReachBothFetchShapes() throws {
        for fallback in [false, true] {
            let observable = CovGStreamObservable<ChainStorageItem>()
            let trigger = CovGTriggerObserver()
            let proxy = DataProviderProxyTrigger()
            proxy.delegate = trigger
            let source = StorageProviderSource<String>(
                itemIdentifier: "era", codingPath: .currentEra, runtimeService: CovGHistoryRuntime(),
                provider: observable.provider(result: .failure(NSError(domain: "CovG.provider", code: 86))),
                trigger: proxy, shouldUseFallback: fallback
            )
            waitUntil { trigger.count == 1 }
            XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation(by: "era"))) {
                XCTAssertEqual(($0 as NSError).code, 86)
            }
            XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation(page: 0))) {
                XCTAssertEqual(($0 as NSError).code, 86)
            }
        }
        let runtime = try StakingConstantRuntime()
        runtime.failure = NSError(domain: "CovG.runtime", code: 87)
        for fallback in [false, true] {
            let observable = CovGStreamObservable<ChainStorageItem>()
            let trigger = CovGTriggerObserver()
            let proxy = DataProviderProxyTrigger()
            proxy.delegate = trigger
            let source = StorageProviderSource<String>(
                itemIdentifier: "era", codingPath: .currentEra, runtimeService: runtime,
                provider: observable.provider(result: .success([ChainStorageItem(identifier: "era", data: Data([1]))])),
                trigger: proxy, shouldUseFallback: fallback
            )
            waitUntil { trigger.count == 1 }
            XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation(page: 0))) {
                XCTAssertEqual(($0 as NSError).code, 87)
            }
        }
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate())
    }
}

final class CovGStreamObservable<T: RobinHood.Identifiable>: DataProviderRepositoryObservable {
    private let lock = NSLock()
    private var observation: (DispatchQueue, ([DataProviderChange<T>]) -> Void)?
    var isObserved: Bool {
        lock.lock(); defer { lock.unlock() }; return observation != nil
    }

    func start(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func stop(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func addObserver(_: AnyObject, deliverOn queue: DispatchQueue, executing updateBlock: @escaping ([DataProviderChange<T>]) -> Void) {
        lock.lock(); observation = (queue, updateBlock); lock.unlock()
    }

    func removeObserver(_: AnyObject) {
        lock.lock(); observation = nil; lock.unlock()
    }

    func emit(_ changes: [DataProviderChange<T>]) {
        lock.lock(); let current = observation; lock.unlock()
        XCTAssertNotNil(current)
        current?.0.async { current?.1(changes) }
    }

    func provider(result: Result<[T], Error>) -> StreamableProvider<T> {
        StreamableProvider(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<T>()),
            repository: AnyDataProviderRepository(CovGFetchRepository<T>(result: result)),
            observable: AnyDataProviderRepositoryObservable(self), operationManager: OperationManager()
        )
    }
}

private final class CovGTriggerObserver: DataProviderTriggerDelegate {
    private let lock = NSLock()
    private var value = 0
    var count: Int {
        lock.lock(); defer { lock.unlock() }; return value
    }

    func didTrigger() {
        lock.lock(); value += 1; lock.unlock()
    }
}
