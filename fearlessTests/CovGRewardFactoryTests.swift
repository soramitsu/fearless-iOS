@testable import fearless
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest

final class CovGRewardFactoryTests: XCTestCase {
    func testGiantsquidAndSoraRequestsPreserveBoundsAndDecodeRewards() throws {
        let chain = try CovGOperationFixtures.chain()
        let address = try Data(repeating: 7, count: 32).toAddress(using: .substrate(42))
        let url = try XCTUnwrap(URL(string: "https://reward.invalid/graphql"))
        let factories: [RewardOperationFactoryProtocol] = [
            GiantsquidRewardOperationFactory(url: url, chain: chain), SoraRewardOperationFactory(url: url, chain: chain),
        ]
        for factory in factories {
            for bounds in [(nil, nil), (Int64(100), nil), (nil, Int64(200)), (Int64(100), Int64(200))] {
                let operation = factory.createHistoryOperation(address: address, startTimestamp: bounds.0, endTimestamp: bounds.1)
                let network = try XCTUnwrap(operation as? NetworkOperation<RewardOrSlashResponse>)
                let query = try CovGOperationFixtures.query(network)
                XCTAssertTrue(query.contains("stakingRewards"))
                XCTAssertEqual(query.contains("timestamp_gte"), bounds.0 != nil)
                XCTAssertEqual(query.contains("timestamp_lte"), bounds.1 != nil)
                try CovGOperationFixtures.respond(network, json: #"{"data":{"stakingRewards":[{"id":"reward","amount":"53","era":5,"timestamp":"2024-01-01T00:00:00.000Z"}]}}"#)
                let response = try CovGOperationFixtures.run(operation)
                XCTAssertEqual(response.data.map(\.identifier), ["reward"])
                XCTAssertEqual(response.data.first?.rewardInfo?.amount, "53")
                XCTAssertEqual(response.data.first?.rewardInfo?.isReward, true)
                checkErrors(network)
            }
            XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createDelegatorRewardsOperation(address: address, startTimestamp: nil, endTimestamp: nil)))
        }
    }

    func testGiantAndSoraMissingURLAndReleasedFactoryFailBeforeNetworking() throws {
        let chain = try CovGOperationFixtures.chain()
        let address = try Data(repeating: 7, count: 32).toAddress(using: .substrate(42))
        for factory in [GiantsquidRewardOperationFactory(url: nil, chain: chain) as RewardOperationFactoryProtocol,
                        SoraRewardOperationFactory(url: nil, chain: chain)]
        {
            let operation = try XCTUnwrap(factory.createHistoryOperation(address: address, startTimestamp: nil, endTimestamp: nil) as? NetworkOperation<RewardOrSlashResponse>)
            XCTAssertThrowsError(try operation.requestFactory.createRequest())
        }
        var factory: SoraRewardOperationFactory? = SoraRewardOperationFactory(url: URL(string: "https://reward.invalid"), chain: chain)
        let operation = try XCTUnwrap(factory?.createHistoryOperation(address: address, startTimestamp: nil, endTimestamp: nil) as? NetworkOperation<RewardOrSlashResponse>)
        factory = nil
        XCTAssertThrowsError(try operation.requestFactory.createRequest())
        let invalid = GiantsquidRewardOperationFactory(url: URL(string: "https://reward.invalid"), chain: chain)
        let invalidOperation = try XCTUnwrap(invalid.createHistoryOperation(address: "invalid", startTimestamp: nil, endTimestamp: nil) as? NetworkOperation<RewardOrSlashResponse>)
        XCTAssertThrowsError(try invalidOperation.requestFactory.createRequest())
    }

    func testSubqueryAndArrowsquidHistoryDecodeAndRejectGraphQLErrors() throws {
        let url = URL(string: "https://reward.invalid/graphql")
        let factories: [RewardOperationFactoryProtocol] = [SubqueryRewardOperationFactory(url: url), ArrowsquidRewardOperationFactory(url: url)]
        for (index, factory) in factories.enumerated() {
            for bounds in [(nil, nil), (Int64(100), nil), (nil, Int64(200)), (Int64(100), Int64(200))] {
                let network = try XCTUnwrap(factory
                    .createHistoryOperation(address: "owner", startTimestamp: bounds.0, endTimestamp: bounds.1) as? NetworkOperation<RewardOrSlashResponse>)
                let query = try CovGOperationFixtures.query(network)
                XCTAssertTrue(query.contains("owner"))
                XCTAssertEqual(query.contains(index == 0 ? "greaterThanOrEqualTo" : "timestamp_gte"), bounds.0 != nil)
                XCTAssertEqual(query.contains(index == 0 ? "lessThanOrEqualTo" : "timestamp_lte"), bounds.1 != nil)
                let node = #"{"id":"r","timestamp":"100","address":"owner","reward":{"amount":"53","isReward":true,"era":5,"eventIdx":6}}"#
                let body = index == 0 ? "{\"data\":{\"historyElements\":{\"nodes\":[\(node)]}}}" : "{\"data\":{\"historyElements\":[\(node)]}}"
                try CovGOperationFixtures.respond(network, json: body)
                let response = try CovGOperationFixtures.run(network)
                XCTAssertEqual(response.data.map(\.identifier), ["r"])
                XCTAssertEqual(response.data.first?.rewardInfo?.amount, "53")
                checkErrors(network)
            }
        }
    }

    func testDelegatorRequestsDecodeEmptyPagesAndHandleInvalidBounds() throws {
        for factory in [SubqueryRewardOperationFactory(url: URL(string: "https://reward.invalid")) as RewardOperationFactoryProtocol,
                        ArrowsquidRewardOperationFactory(url: URL(string: "https://reward.invalid"))]
        {
            let operation = factory.createDelegatorRewardsOperation(address: "owner", startTimestamp: 100, endTimestamp: 200)
            let network = try XCTUnwrap(operation as? NetworkOperation<RewardHistoryResponseProtocol>)
            XCTAssertTrue(try CovGOperationFixtures.query(network).contains("owner"))
            let json = factory is SubqueryRewardOperationFactory ? #"{"data":{"delegators":{"nodes":[]}}}"# : #"{"data":{"historyElements":[]}}"#
            try CovGOperationFixtures.respond(network, json: json)
            XCTAssertTrue(try CovGOperationFixtures.run(network).rewardHistory(for: "owner").isEmpty)
            checkErrors(network)
            for bounds in [(Int64(-1), Int64(200)), (Int64(200), Int64(100))] {
                XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createHistoryOperation(address: "owner", startTimestamp: bounds.0, endTimestamp: bounds.1)))
                XCTAssertThrowsError(try CovGOperationFixtures.run(factory.createDelegatorRewardsOperation(address: "owner", startTimestamp: bounds.0, endTimestamp: bounds.1)))
            }
        }
    }

    private func checkErrors<T>(_ network: NetworkOperation<T>) {
        CovGOperationFixtures.checkNetworkFailures(network)
        XCTAssertThrowsError(try network.resultFactory.createResult(data: Data(#"""
        {"errors":[{"message":"rejected"}]}
        """#.utf8), response: CovGOperationFixtures.response(), error: nil).get()) {
            XCTAssertEqual(($0 as? GraphQLError)?.message, "rejected")
        }
    }
}

final class CovGStakeSourceTests: XCTestCase {
    func testStakeChangesIgnoreMalformedNodesAndPreserveTypedAmounts() throws {
        let source = try SubqueryStakeSource(address: "owner", url: XCTUnwrap(URL(string: "https://stake.invalid")))
        let wrapper = source.fetchOperation()
        let network = try CovGOperationFixtures.network(wrapper, as: [SubqueryStakeChangeData]?.self)
        XCTAssertTrue(try CovGOperationFixtures.query(network).contains("TIMESTAMP_ASC"))
        let json = #"{"data":{"query":{"stakeChanges":{"nodes":[{"id":"b","address":"owner","timestamp":"100","amount":"53","accumulatedAmount":"100","type":"bonded"},{}]}}}}"#
        try CovGOperationFixtures.respond(network, json: json)
        let changes = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].eventId, "b")
        XCTAssertEqual(changes[0].timestamp, 100)
        XCTAssertEqual(changes[0].amount, 53)
        XCTAssertEqual(changes[0].accumulatedAmount, 100)
        XCTAssertEqual(changes[0].type, .bonded)
        for type in [SubqueryStakeChangeData.SubqueryStakeChangeType.bonded, .unbonded, .rewarded, .slashed] {
            XCTAssertFalse(type.title(for: Locale(identifier: "en_US")).isEmpty)
        }
        let empty = source.fetchOperation()
        let emptyNetwork = try CovGOperationFixtures.network(empty, as: [SubqueryStakeChangeData]?.self)
        try CovGOperationFixtures.respond(emptyNetwork, json: "{}")
        XCTAssertNil(try CovGOperationFixtures.run(empty))
        CovGOperationFixtures.checkNetworkFailures(network)
    }

    func testEraValidatorRequestsIncludeOptionalRangeAndIgnoreMalformedRows() throws {
        let source = try SubqueryEraStakersInfoSource(url: XCTUnwrap(URL(string: "https://stake.invalid")), address: "owner")
        for range: EraRange? in [nil, EraRange(start: 3, end: 5)] {
            let wrapper = source.fetch { range }
            let network = try CovGOperationFixtures.network(wrapper, as: [SubqueryEraValidatorInfo]?.self)
            let query = try CovGOperationFixtures.query(network)
            XCTAssertTrue(query.contains("owner"))
            XCTAssertEqual(query.contains("greaterThanOrEqualTo: 3"), range != nil)
            try CovGOperationFixtures.respond(network, json: #"{"data":{"query":{"eraValidatorInfos":{"nodes":[{"address":"validator","era":4},{}]}}}}"#)
            let values = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(values.count, 1)
            XCTAssertEqual(values.first?.era, 4)
            XCTAssertEqual(values.first?.address, "validator")
            CovGOperationFixtures.checkNetworkFailures(network)
        }
    }
}
