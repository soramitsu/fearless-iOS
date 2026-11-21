import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovGProviderFactoryTests: XCTestCase {
    func testHistoryProviderFetchesFirstPageThroughOperationFactory() throws {
        let operationFactory = CovGHistoryPageFactory()
        let factory = HistoryDataProviderFactory(operationFactory: operationFactory)
        let chain = try CovGOperationFixtures.chain()
        let filters: [WalletTransactionHistoryFilter] = [.init(type: .transfer, selected: true)]
        let provider = try factory.createDataProvider(
            for: "owner", asset: CovGOperationFixtures.asset, chain: chain,
            targetIdentifier: "cov-g-history-\(UUID().uuidString)", filters: filters
        )
        var pages: [AssetTransactionPageData?] = []
        provider.addObserver(
            self, deliverOn: .main,
            executing: { changes in pages.append(changes.reduceToLastChange()) },
            failing: { XCTFail("Unexpected history failure \($0)") },
            options: DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
        )
        waitUntil { !pages.compactMap { $0 }.isEmpty }
        XCTAssertEqual(pages.compactMap { $0 }.last?.transactions.map(\.transactionId), ["cov-g-tx"])
        XCTAssertEqual(operationFactory.requests.first?.address, "owner")
        XCTAssertEqual(operationFactory.requests.first?.count, HistoryDataProviderFactory.Constants.historyDefaultPageSize)
        XCTAssertEqual(operationFactory.requests.first?.filters, 1)
        provider.removeObserver(self)
    }

    func testJsonFactoryCachesLiveProvidersOnlyWhenCachingIsEnabled() throws {
        let url = try XCTUnwrap(URL(string: "https://json.invalid/cov-g-\(UUID().uuidString).json"))
        let cached = JsonDataProviderFactory(storageFacade: SubstrateStorageTestFacade())
        let first: AnySingleValueProvider<CrowdloanDisplayInfoList> = try cached.getJson(for: url)
        let second: AnySingleValueProvider<CrowdloanDisplayInfoList> = try cached.getJson(for: url)
        XCTAssertTrue(first.executionQueue === second.executionQueue)
        let uncached = JsonDataProviderFactory(storageFacade: SubstrateStorageTestFacade(), useCache: false)
        let third: AnySingleValueProvider<CrowdloanDisplayInfoList> = try uncached.getJson(for: url)
        XCTAssertFalse(uncached.useCache)
        XCTAssertTrue(cached.useCache)
        XCTAssertFalse(third.executionQueue === first.executionQueue)
        withExtendedLifetime([first, second, third]) {}
    }

    func testJsonSubscriberForwardsDisplayInfoAndFailures() throws {
        let provider = CovGJsonProvider()
        let subscriber = CovGJsonSubscriber(factory: CovGJsonFactory(provider: provider))
        let url = try XCTUnwrap(URL(string: "https://json.invalid/crowdloans.json"))
        XCTAssertNotNil(try subscriber.subscribeToCrowdloanDisplayInfo(for: url, chainId: "chain"))
        let info = CrowdloanDisplayInfo(
            paraid: "2000", name: "Para", token: "PARA", description: "Description", website: "https://para.invalid",
            icon: "https://para.invalid/icon.png", rewardRate: nil, endingBlock: nil, disabled: nil, flow: nil
        )
        provider.update?([.insert(newItem: [info])])
        XCTAssertEqual(try XCTUnwrap(subscriber.results.last).get()?.map(\.paraid), ["2000"])
        XCTAssertEqual(subscriber.urls.last, url)
        XCTAssertEqual(subscriber.chains.last, "chain")
        provider.failure?(NSError(domain: "CovG.json", code: 69))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.results.last).get()) { XCTAssertEqual(($0 as NSError).code, 69) }
        XCTAssertNil(info.flowIfSupported)
        XCTAssertEqual([info].toMap().keys.sorted(), [2000])
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate())
    }
}

private final class CovGHistoryPageFactory: HistoryOperationFactoryProtocol {
    struct Request {
        let address: String
        let count: Int
        let filters: Int
    }

    private let lock = NSLock()
    private var recorded: [Request] = []
    var requests: [Request] {
        lock.lock(); defer { lock.unlock() }; return recorded
    }

    func fetchTransactionHistoryOperation(
        asset _: AssetModel, chain _: ChainModel, address: String, filters: [WalletTransactionHistoryFilter], pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        lock.lock(); recorded.append(Request(address: address, count: pagination.count, filters: filters.count)); lock.unlock()
        let transaction = AssetTransactionData(
            transactionId: "cov-g-tx", status: .commited, assetId: "0", peerId: "", peerFirstName: nil, peerLastName: nil,
            peerName: "peer", details: "", amount: AmountDecimal(value: 1), fees: [], timestamp: 1, type: "INCOMING",
            reason: nil, context: nil
        )
        let operation = BaseOperation<AssetTransactionPageData?>()
        operation.result = .success(AssetTransactionPageData(transactions: [transaction]))
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

private final class CovGJsonSubscriber: JsonLocalStorageSubscriber, JsonLocalSubscriptionHandler {
    let jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol
    private(set) var results: [Result<CrowdloanDisplayInfoList?, Error>] = []
    private(set) var urls: [URL] = []
    private(set) var chains: [ChainModel.Id] = []

    init(factory: JsonDataProviderFactoryProtocol) {
        jsonLocalSubscriptionFactory = factory
    }

    func handleCrowdloanDisplayInfo(result: Result<CrowdloanDisplayInfoList?, Error>, url: URL, chainId: ChainModel.Id) {
        results.append(result)
        urls.append(url)
        chains.append(chainId)
    }
}

private final class CovGJsonFactory: JsonDataProviderFactoryProtocol {
    let provider: CovGJsonProvider
    init(provider: CovGJsonProvider) {
        self.provider = provider
    }

    func getJson<T: Codable & Equatable>(for _: URL) throws -> AnySingleValueProvider<T> {
        let erased = AnySingleValueProvider<CrowdloanDisplayInfoList>(provider)
        return try XCTUnwrap(erased as? AnySingleValueProvider<T>)
    }
}

final class CovGJsonProvider: SingleValueProviderProtocol {
    typealias Model = CrowdloanDisplayInfoList

    let executionQueue = OperationQueue()
    var update: (([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void)?
    var failure: ((Error) -> Void)?

    func fetch(with completionBlock: ((Result<CrowdloanDisplayInfoList?, Error>?) -> Void)?) -> CompoundOperationWrapper<CrowdloanDisplayInfoList?> {
        completionBlock?(.success(nil))
        return CompoundOperationWrapper(targetOperation: ClosureOperation { nil })
    }

    func addObserver(
        _: AnyObject, deliverOn _: DispatchQueue?, executing: @escaping ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void,
        failing: @escaping (Error) -> Void, options _: DataProviderObserverOptions
    ) {
        update = executing
        failure = failing
    }

    func removeObserver(_: AnyObject) {
        update = nil
        failure = nil
    }

    func refresh() {}
}
