import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovFStkCrowdloanFactory: CrowdloanOperationFactoryProtocol {
    private let lock = NSLock()
    private var storedAccounts: [Data] = []
    private var storedIndexes: [TrieOrFundIndex] = []
    private var storedConnections: [AnyObject] = []
    var crowdloans: Result<[Crowdloan], Error> = .success([])
    var contributions: [TrieOrFundIndex: CrowdloanContribution] = [:]
    var contributionError: Error?

    var requestedAccounts: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return storedAccounts
    }

    var requestedIndexes: [TrieOrFundIndex] {
        lock.lock()
        defer { lock.unlock() }
        return storedIndexes
    }

    var connections: [AnyObject] {
        lock.lock()
        defer { lock.unlock() }
        return storedConnections
    }

    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Crowdloan]> {
        lock.lock()
        storedConnections.append(connection)
        lock.unlock()
        let result = crowdloans
        return CompoundOperationWrapper(targetOperation: ClosureOperation<[Crowdloan]> { try result.get() })
    }

    func fetchContributionOperation(
        connection: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol,
        accountId: Data,
        trieOrFundIndex: TrieOrFundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        lock.lock()
        storedAccounts.append(accountId)
        storedIndexes.append(trieOrFundIndex)
        storedConnections.append(connection)
        lock.unlock()
        let contribution = contributions[trieOrFundIndex]
        let error = contributionError
        let operation = ClosureOperation<CrowdloanContributionResponse> {
            if let error = error {
                throw error
            }
            return CrowdloanContributionResponse(accountId: accountId, trieOrFundIndex: trieOrFundIndex, contribution: contribution)
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchLeaseInfoOperation(
        connection _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol,
        paraIds _: [UInt32]
    ) -> CompoundOperationWrapper<[ParachainLeaseInfo]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation<[ParachainLeaseInfo]> { [] })
    }
}

final class CovFStkCrowdloanServiceTests: XCTestCase {
    private func makeService(_ factory: CovFStkCrowdloanFactory, engine: CovFStkEngine) -> CrowdloanServiceDefault {
        CrowdloanServiceDefault(
            crowdloanOperationFactory: factory,
            runtimeService: CovFStkRuntime(.empty),
            connection: engine,
            chainAsset: CovFStkFixtures.chainAsset,
            operationManager: OperationManager()
        )
    }

    func testContributionsAreFetchedForEveryFundAndOnlyExistingOnesAreKept() async throws {
        let factory = CovFStkCrowdloanFactory()
        let engine = CovFStkEngine()
        let firstFunds = try CovFStkFixtures.funds(index: 7)
        let secondFunds = try CovFStkFixtures.funds(index: 8)
        factory.crowdloans = .success([
            Crowdloan(paraId: 2000, fundInfo: firstFunds),
            Crowdloan(paraId: 2001, fundInfo: secondFunds)
        ])
        factory.contributions = [.fundIndex(7): CrowdloanContribution(balance: 700, memo: Data([0x01]))]

        let contributions = try await makeService(factory, engine: engine).fetchContributions(accountId: CovFStkFixtures.accountId)

        XCTAssertEqual(Array(contributions.keys), [.fundIndex(7)])
        XCTAssertEqual(contributions[.fundIndex(7)]?.balance, 700)
        XCTAssertEqual(contributions[.fundIndex(7)]?.memo, Data([0x01]))
        XCTAssertEqual(factory.requestedIndexes, [.fundIndex(7), .fundIndex(8)])
        XCTAssertEqual(factory.requestedAccounts, [CovFStkFixtures.accountId, CovFStkFixtures.accountId])
        XCTAssertEqual(factory.connections.count, 3)
        XCTAssertTrue(factory.connections.allSatisfy { $0 === engine })
    }

    func testNoCrowdloansGiveNoContributions() async throws {
        let factory = CovFStkCrowdloanFactory()

        let contributions = try await makeService(factory, engine: CovFStkEngine()).fetchContributions(accountId: CovFStkFixtures.accountId)

        XCTAssertTrue(contributions.isEmpty)
        XCTAssertTrue(factory.requestedIndexes.isEmpty)
    }

    func testCrowdloanFetchFailureIsThrown() async throws {
        let factory = CovFStkCrowdloanFactory()
        factory.crowdloans = .failure(CovFStkError.stub("crowdloans"))

        do {
            _ = try await makeService(factory, engine: CovFStkEngine()).fetchContributions(accountId: CovFStkFixtures.accountId)
            XCTFail("Expected the crowdloan error")
        } catch {
            XCTAssertEqual(error as? CovFStkError, .stub("crowdloans"))
        }
        XCTAssertTrue(factory.requestedIndexes.isEmpty)
    }

    func testContributionFetchFailureIsThrown() async throws {
        let factory = CovFStkCrowdloanFactory()
        let funds = try CovFStkFixtures.funds(index: 3)
        factory.crowdloans = .success([Crowdloan(paraId: 2000, fundInfo: funds)])
        factory.contributionError = CovFStkError.stub("contribution")

        do {
            _ = try await makeService(factory, engine: CovFStkEngine()).fetchContributions(accountId: CovFStkFixtures.accountId)
            XCTFail("Expected the contribution error")
        } catch {
            XCTAssertEqual(error as? CovFStkError, .stub("contribution"))
        }
        XCTAssertEqual(factory.requestedIndexes, [.fundIndex(3)])
    }
}

final class CovFStkHistoryFactory: HistoryOperationFactoryProtocol {
    private let lock = NSLock()
    private var storedAddresses: [String] = []
    private var storedFilters: [[String]] = []
    private var storedPaginations: [Pagination] = []
    private var storedChainIds: [String] = []
    private let makeWrapper: () -> CompoundOperationWrapper<AssetTransactionPageData?>

    init(_ makeWrapper: @escaping () -> CompoundOperationWrapper<AssetTransactionPageData?>) {
        self.makeWrapper = makeWrapper
    }

    var addresses: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedAddresses
    }

    var filterIds: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storedFilters
    }

    var paginations: [Pagination] {
        lock.lock()
        defer { lock.unlock() }
        return storedPaginations
    }

    var chainIds: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedChainIds
    }

    func fetchTransactionHistoryOperation(
        asset _: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        lock.lock()
        storedAddresses.append(address)
        storedFilters.append(filters.map(\.id))
        storedPaginations.append(pagination)
        storedChainIds.append(chain.chainId)
        lock.unlock()
        return makeWrapper()
    }
}

final class CovFStkHistoryServiceTests: XCTestCase {
    private let chainAsset = CovFStkFixtures.chainAsset
    private let pagination = Pagination(count: 20, context: ["page": "2"])

    func testHistoryForwardsTheRequestAndCompletesOnTheRequestedQueue() throws {
        let page = AssetTransactionPageData(transactions: [], context: ["after": "cursor"])
        let factory = CovFStkHistoryFactory {
            CompoundOperationWrapper(targetOperation: ClosureOperation<AssetTransactionPageData?> { page })
        }
        let service = HistoryService(operationFactory: factory, operationQueue: OperationQueue())
        let queue = DispatchQueue(label: "covfstk.history")
        let key = DispatchSpecificKey<String>()
        queue.setSpecific(key: key, value: "history")
        let done = covFStkExpectation("completion")
        var received: Result<AssetTransactionPageData?, Error>?
        var completionQueue: String?

        service.fetchTransactionHistory(
            for: "ADDR",
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            filters: [WalletTransactionHistoryFilter(type: .swap, selected: true)],
            pagination: pagination,
            runCompletionIn: queue
        ) { result in
            received = result
            completionQueue = DispatchQueue.getSpecific(key: key)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(completionQueue, "history")
        XCTAssertEqual(factory.addresses, ["ADDR"])
        XCTAssertEqual(factory.filterIds, [["swap"]])
        XCTAssertEqual(factory.paginations, [pagination])
        XCTAssertEqual(factory.chainIds, [chainAsset.chain.chainId])
        switch received {
        case let .success(value)?:
            XCTAssertEqual(value, page)
        case let .failure(error)?:
            XCTFail("Unexpected error \(error)")
        case .none:
            XCTFail("No result")
        }
    }

    func testHistoryFailureReachesTheCompletion() {
        let factory = CovFStkHistoryFactory {
            CompoundOperationWrapper(targetOperation: ClosureOperation<AssetTransactionPageData?> {
                throw CovFStkError.stub("history")
            })
        }
        let service = HistoryService(operationFactory: factory, operationQueue: OperationQueue())
        let done = covFStkExpectation("completion")
        var failure: Error?

        service.fetchTransactionHistory(
            for: "ADDR",
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            filters: [],
            pagination: pagination,
            runCompletionIn: .main
        ) { result in
            if case let .failure(error)? = result {
                failure = error
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(failure as? CovFStkError, .stub("history"))
    }

    func testCancelledHistoryNeverCompletes() throws {
        let factory = CovFStkHistoryFactory {
            let wrapper = CompoundOperationWrapper(targetOperation: ClosureOperation<AssetTransactionPageData?> { nil })
            wrapper.cancel()
            return wrapper
        }
        let queue = OperationQueue()
        let service = HistoryService(operationFactory: factory, operationQueue: queue)
        let completed = XCTestExpectation(description: "no completion")
        completed.isInverted = true

        let call = service.fetchTransactionHistory(
            for: "ADDR",
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            filters: [],
            pagination: pagination,
            runCompletionIn: .main
        ) { _ in
            completed.fulfill()
        }
        queue.waitUntilAllOperationsAreFinished()
        wait(for: [completed], timeout: 0.5)

        let wrapper = try XCTUnwrap(call as? CompoundOperationWrapper<AssetTransactionPageData?>)
        XCTAssertTrue(wrapper.targetOperation.isCancelled)
        XCTAssertTrue(wrapper.targetOperation.isFinished)
        XCTAssertNil(wrapper.targetOperation.result)
    }
}
