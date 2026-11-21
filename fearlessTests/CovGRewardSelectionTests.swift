import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovGRewardSelectionTests: XCTestCase {
    func testRewardFactoryFollowsStakingExplorerTypeAndDefaultsToSubsquid() throws {
        let url = "https://staking.invalid/graphql"
        let cases: [(String?, String)] = [
            ("subquery", "SubqueryRewardOperationFactory"), ("subsquid", "ArrowsquidRewardOperationFactory"),
            ("giantsquid", "GiantsquidRewardOperationFactory"), ("sora", "SoraRewardOperationFactory"),
            ("etherscan", "GiantsquidRewardOperationFactory"), ("reef", "GiantsquidRewardOperationFactory"),
            (nil, "ArrowsquidRewardOperationFactory"),
        ]
        for (type, expected) in cases {
            let staking = try type.map { try XCTUnwrap(ChainModel.BlockExplorer(type: $0, url: XCTUnwrap(URL(string: url)))) }
            let chain = ChainModel(
                rank: nil, disabled: false, chainId: "cov-g-rewards", paraId: nil, name: "Coverage chain",
                assets: [CovGOperationFixtures.asset], xcm: nil, nodes: [], addressPrefix: 42, icon: nil, options: [],
                externalApi: staking.map { ChainModel.ExternalApiSet(staking: $0) }, iosMinAppVersion: nil, identityChain: nil
            )
            let factory = RewardOperationFactory.factory(chain: chain)
            XCTAssertEqual(String(describing: Swift.type(of: factory)), expected, "\(String(describing: type))")
        }
    }

    func testDefaultHistoryOperationRequestsUnboundedRange() throws {
        let recorder = CovGRewardRecorder()
        let operation = recorder.createHistoryOperation(address: "owner")
        XCTAssertEqual(recorder.calls.count, 1)
        XCTAssertEqual(recorder.calls.first?.0, "owner")
        XCTAssertNil(recorder.calls.first?.1)
        XCTAssertNil(recorder.calls.first?.2)
        XCTAssertThrowsError(try CovGOperationFixtures.run(operation))
    }
}

private final class CovGRewardRecorder: RewardOperationFactoryProtocol {
    private(set) var calls: [(String, Int64?, Int64?)] = []

    func createHistoryOperation(address: String, startTimestamp: Int64?, endTimestamp: Int64?) -> BaseOperation<RewardOrSlashResponse> {
        calls.append((address, startTimestamp, endTimestamp))
        let operation = BaseOperation<RewardOrSlashResponse>()
        operation.result = .failure(NSError(domain: "CovG.reward", code: 71))
        return operation
    }

    func createDelegatorRewardsOperation(
        address _: String, startTimestamp _: Int64?, endTimestamp _: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
        let operation = BaseOperation<RewardHistoryResponseProtocol>()
        operation.result = .failure(NSError(domain: "CovG.reward", code: 72))
        return operation
    }
}
