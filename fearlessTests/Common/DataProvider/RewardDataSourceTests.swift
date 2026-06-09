import XCTest
@testable import fearless
import RobinHood

final class RewardDataSourceTests: XCTestCase {
    func testFetchOperation_whenRemoteRewardsReceived_thenReturnsNetTotalReward() throws {
        let address = "test-address"
        let source = try createSource(
            address: address,
            remoteResult: .success([
                RewardData(id: "reward", address: address, amount: "1000000000000", isReward: true),
                RewardData(id: "slash", address: address, amount: "250000000000", isReward: false),
                RewardData(id: "decimalReward", address: address, amount: "0.5", isReward: true)
            ])
        )

        let reward = try executeFetchOperation(source)

        XCTAssertEqual(reward?.address, address)
        XCTAssertEqual(reward?.amount.decimalValue, Decimal(string: "1.25"))
    }

    func testFetchOperation_whenRemoteFetchFails_thenReturnsError() throws {
        let source = try createSource(
            address: "test-address",
            remoteResult: .failure(RewardDataSourceTestError.remoteFailure)
        )

        XCTAssertThrowsError(try executeFetchOperation(source)) { error in
            XCTAssertEqual(error as? RewardDataSourceTestError, .remoteFailure)
        }
    }

    private func createSource(
        address: String,
        remoteResult: Result<[RewardOrSlashData], Error>
    ) throws -> SubqueryRewardSource {
        let trigger = DataProviderProxyTrigger()
        let triggerObserver = TriggerObserver(expectation: expectation(description: "Reward source triggered"))
        trigger.delegate = triggerObserver

        let repository = InMemoryDataProviderRepository<SingleValueProviderObject>()
        let source = SubqueryRewardSource(
            address: address,
            assetPrecision: 12,
            targetIdentifier: address,
            repository: AnyDataProviderRepository(repository),
            rewardsFetcher: StubRewardsFetcher(result: remoteResult),
            trigger: trigger,
            operationManager: OperationManager()
        )

        wait(for: [triggerObserver.expectation], timeout: Constants.defaultExpectationDuration)

        return source
    }

    private func executeFetchOperation(_ source: SubqueryRewardSource) throws -> TotalRewardItem? {
        let wrapper = source.fetchOperation()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
    }
}

private enum RewardDataSourceTestError: Error {
    case remoteFailure
}

private final class StubRewardsFetcher: StakingRewardsFetcher {
    let result: Result<[RewardOrSlashData], Error>

    init(result: Result<[RewardOrSlashData], Error>) {
        self.result = result
    }

    func fetchAllRewards(
        address _: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) async throws -> [RewardOrSlashData] {
        try result.get()
    }
}

private final class TriggerObserver: DataProviderTriggerDelegate {
    let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didTrigger() {
        expectation.fulfill()
    }
}

private struct RewardData: RewardOrSlashData {
    let identifier: String
    let timestamp: String
    let address: String
    let rewardInfo: RewardOrSlash?

    init(id: String, address: String, amount: String, isReward: Bool) {
        identifier = id
        timestamp = "0"
        self.address = address
        rewardInfo = RewardInfo(amount: amount, isReward: isReward)
    }
}

private struct RewardInfo: RewardOrSlash {
    let amount: String
    let isReward: Bool
    let era: Int? = nil
    let validator: String? = nil
    let stash: String? = nil
    let eventIdx: String? = nil
    let assetId: String? = nil
}
