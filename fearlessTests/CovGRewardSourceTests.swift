@testable import fearless
import Foundation
import RobinHood
import XCTest

final class CovGRewardSourceTests: XCTestCase {
    func testRewardsSubtractSlashesIgnoreMissingInfoAndSupportDecimalAmounts() throws {
        let json = #"""
        [{"id":"1",
        "timestamp":"1",
        "address":"owner",
        "reward":{"amount":"1000",
        "isReward":true}},
        {"id":"2",
        "timestamp":"2",
        "address":"owner",
        "reward":{"amount":"200",
        "isReward":false}},
        {"id":"3",
        "timestamp":"3",
        "address":"owner",
        "reward":{"amount":"1.5",
        "isReward":true}},
        {"id":"4",
        "timestamp":"4",
        "address":"owner",
        "reward":{"amount":"invalid",
        "isReward":true}},
        {"id":"5",
        "timestamp":"5",
        "address":"owner"}]
        """#
        let items = try JSONDecoder().decode([SubqueryHistoryElement].self, from: Data(json.utf8))
        let trigger = CovGRewardTrigger()
        let fetcher = CovGRewardsFetcher(result: .success(items))
        let source = SubqueryRewardSource(
            address: "owner", assetPrecision: 2, targetIdentifier: "reward",
            repository: AnyDataProviderRepository(InMemoryDataProviderRepository<SingleValueProviderObject>()),
            rewardsFetcher: fetcher, trigger: trigger, operationManager: OperationManager()
        )
        waitUntil { trigger.count > 0 }
        let reward = try XCTUnwrap(CovGOperationFixtures.run(source.fetchOperation()))
        XCTAssertEqual(reward.address, "owner")
        XCTAssertEqual(reward.amount.decimalValue, Decimal(string: "9.5"))
        XCTAssertEqual(fetcher.address, "owner")
        XCTAssertNil(fetcher.start)
        XCTAssertNil(fetcher.end)
    }

    func testRemoteFailureIsReportedThenLocalCachedRewardCanBeRead() throws {
        let repository = InMemoryDataProviderRepository<SingleValueProviderObject>()
        let cached = TotalRewardItem(address: "owner", amount: AmountDecimal(value: 7))
        let payload = try JSONEncoder().encode(cached)
        try CovGOperationFixtures.run(repository.saveOperation({ [SingleValueProviderObject(identifier: "reward", payload: payload)] }, { [] }))
        let trigger = CovGRewardTrigger()
        let source = SubqueryRewardSource(
            address: "owner", assetPrecision: 2, targetIdentifier: "reward", repository: AnyDataProviderRepository(repository),
            rewardsFetcher: CovGRewardsFetcher(result: .failure(NSError(domain: "CovG.reward", code: 88))),
            trigger: trigger, operationManager: OperationManager()
        )
        waitUntil { trigger.count > 0 }
        XCTAssertThrowsError(try CovGOperationFixtures.run(source.fetchOperation())) { XCTAssertEqual(($0 as NSError).code, 88) }
        XCTAssertEqual(try CovGOperationFixtures.run(source.fetchOperation()), cached)
    }

    func testEmptyAndCorruptLocalCacheReturnNilAfterRemoteValueIsConsumed() throws {
        for payload in [nil, Data("invalid".utf8)] as [Data?] {
            let repository = InMemoryDataProviderRepository<SingleValueProviderObject>()
            if let payload {
                try CovGOperationFixtures.run(repository.saveOperation({ [SingleValueProviderObject(identifier: "reward", payload: payload)] }, { [] }))
            }
            let trigger = CovGRewardTrigger()
            let source = SubqueryRewardSource(
                address: "owner", assetPrecision: 2, targetIdentifier: "reward", repository: AnyDataProviderRepository(repository),
                rewardsFetcher: CovGRewardsFetcher(result: .success([])), trigger: trigger, operationManager: OperationManager()
            )
            waitUntil { trigger.count > 0 }
            XCTAssertEqual(try CovGOperationFixtures.run(source.fetchOperation())?.amount.decimalValue, 0)
            XCTAssertNil(try CovGOperationFixtures.run(source.fetchOperation()))
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

private final class CovGRewardsFetcher: StakingRewardsFetcher {
    let result: Result<[RewardOrSlashData], Error>
    var address: String?
    var start: Int64?
    var end: Int64?
    init(result: Result<[RewardOrSlashData], Error>) {
        self.result = result
    }

    func fetchAllRewards(address: String, startTimestamp: Int64?, endTimestamp: Int64?) async throws -> [RewardOrSlashData] {
        self.address = address; start = startTimestamp; end = endTimestamp
        return try result.get()
    }
}

private final class CovGRewardTrigger: DataProviderTriggerProtocol, DataProviderTriggerDelegate {
    var delegate: DataProviderTriggerDelegate? {
        get { self }
        set {}
    }

    private let lock = NSLock()
    private var received = 0
    var count: Int {
        lock.lock(); defer { lock.unlock() }; return received
    }

    func didTrigger() {
        lock.lock(); received += 1; lock.unlock()
    }

    func receive(event _: DataProviderEvent) {}
}
