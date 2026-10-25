import BigInt
import IrohaCrypto
import RobinHood
import SSFModels
import XCTest

@testable import fearless

final class RewardDataSourceTests: XCTestCase {
    private let endpoint = URL(string: "https://example.com/graphql")!
    private let stashAddress = "stashAddress"
    private let validatorAddress = "validatorAddress"

    func testSubqueryRequestAndResponseThreadCollatorAttributionEndToEnd() throws {
        let factory = SubqueryRewardOperationFactory(url: endpoint)
        let operation = try networkOperation(
            factory: factory,
            startTimestamp: 1_700_000_000,
            endTimestamp: 1_700_000_100
        )
        let query = try requestQuery(operation)

        XCTAssertTrue(query.contains("collatorId"))
        XCTAssertTrue(query.contains("roundId"))
        XCTAssertTrue(query.contains("delegatorId"))
        XCTAssertTrue(query.contains("type: { equalTo: 2 }"))
        XCTAssertFalse(query.contains("type: { equalTo: 0 }"))
        XCTAssertTrue(query.contains("greaterThanOrEqualTo: \"1700000000\""))
        XCTAssertTrue(query.contains("lessThanOrEqualTo: \"1700000100\""))

        let response = try decodeResponse(
            operation,
            json: """
            {
              "data": {
                "delegators": {
                  "nodes": [{
                    "id": "stashAddress",
                    "delegatorHistoryElements": {
                      "nodes": [{
                        "id": "subquery-event",
                        "blockNumber": 123,
                        "amount": "456",
                        "type": 2,
                        "timestamp": "1700000000",
                        "delegatorId": "stashAddress",
                        "collatorId": "validatorAddress",
                        "roundId": "42"
                      }]
                    }
                  }]
                }
              }
            }
            """
        )

        let rewards = try mappedRewards(response)
        let weeklyRewards = try mappedWeeklyRewards(response)

        XCTAssertEqual(rewards.count, 1)
        XCTAssertEqual(rewards, weeklyRewards)
        XCTAssertEqual(rewards.first?.eventId, "subquery-event")
        XCTAssertEqual(rewards.first?.timestamp, 1_700_000_000)
        XCTAssertEqual(rewards.first?.validatorAddress, validatorAddress)
        XCTAssertEqual(rewards.first?.era, 42)
        XCTAssertEqual(rewards.first?.stashAddress, stashAddress)
        XCTAssertEqual(rewards.first?.amount, 456)
        XCTAssertEqual(rewards.first?.isReward, true)
    }

    func testSubqueryMalformedAttributionFailsClosedWithoutDroppingAggregateRewards() throws {
        let factory = SubqueryRewardOperationFactory(url: endpoint)
        let operation = try networkOperation(factory: factory)
        let overflowRound = String(UInt64(EraIndex.max) + 1)
        let response = try decodeResponse(
            operation,
            json: """
            {
              "data": {
                "delegators": {
                  "nodes": [{
                    "id": "stashAddress",
                    "delegatorHistoryElements": {
                      "nodes": [
                        {"id":"missing-validator","blockNumber":1,"amount":1,"type":2,"timestamp":"1","delegatorId":"stashAddress","roundId":"1"},
                        {"id":"whitespace-validator","blockNumber":2,"amount":"2","type":2,"timestamp":"2","delegatorId":"stashAddress","collatorId":" validatorAddress ","roundId":"2"},
                        {"id":"missing-round","blockNumber":3,"amount":"3","type":2,"timestamp":"3","delegatorId":"stashAddress","collatorId":"validatorAddress"},
                        {"id":"negative-round","blockNumber":4,"amount":"4","type":2,"timestamp":"4","delegatorId":"stashAddress","collatorId":"validatorAddress","roundId":"-1"},
                        {"id":"overflow-round","blockNumber":5,"amount":"5","type":2,"timestamp":"5","delegatorId":"stashAddress","collatorId":"validatorAddress","roundId":"\(overflowRound)"},
                        {"id":"wrong-types","blockNumber":6,"amount":"6","type":2,"timestamp":"6","delegatorId":"stashAddress","collatorId":7,"roundId":[]},
                        {"id":"non-reward","blockNumber":7,"amount":"7","type":0,"timestamp":"7","delegatorId":"stashAddress","collatorId":"validatorAddress","roundId":"7"},
                        {"id":"invalid-timestamp","blockNumber":8,"amount":"8","type":2,"timestamp":"9223372036854775808","delegatorId":"stashAddress","collatorId":"validatorAddress","roundId":"8"},
                        {"id":"foreign-delegator","blockNumber":9,"amount":"9","type":2,"timestamp":"9","delegatorId":"attackerAddress","collatorId":"validatorAddress","roundId":"9"}
                      ]
                    }
                  }, {
                    "id": "attackerAddress",
                    "delegatorHistoryElements": {
                      "nodes": [{"id":"attacker","blockNumber":10,"amount":"10","type":2,"timestamp":"10","delegatorId":"attackerAddress","collatorId":"validatorAddress","roundId":"10"}]
                    }
                  }]
                }
              }
            }
            """
        )

        let rewards = try mappedRewards(response)

        XCTAssertEqual(rewards.count, 7)
        XCTAssertEqual(rewards.map(\.amount), (1 ... 7).map { BigUInt($0) })
        XCTAssertTrue(rewards.prefix(6).allSatisfy { $0.validatorAddress.isEmpty && $0.era == 0 })
        XCTAssertEqual(rewards.last?.validatorAddress, validatorAddress)
        XCTAssertEqual(rewards.last?.era, 7)
        XCTAssertEqual(rewards.last?.isReward, false)
        XCTAssertFalse(rewards.contains {
            ["attacker", "foreign-delegator", "invalid-timestamp"].contains($0.eventId)
        })
    }

    func testSubsquidRequestUsesLiveHistorySchemaAndNumericTimestampBounds() throws {
        let factory = ArrowsquidRewardOperationFactory(url: endpoint)
        let operation = try networkOperation(
            factory: factory,
            startTimestamp: 1_700_000_000,
            endTimestamp: 1_700_000_100
        )
        let query = try requestQuery(operation)

        XCTAssertTrue(query.contains("historyElements("))
        XCTAssertFalse(query.contains("rewards("))
        XCTAssertTrue(query.contains("blockHeight"))
        XCTAssertTrue(query.contains("reward {"))
        XCTAssertTrue(query.contains("validator"))
        XCTAssertTrue(query.contains("era"))
        XCTAssertTrue(query.contains("AND: { timestamp_gte: 1700000000, timestamp_lte: 1700000100 }"))
        XCTAssertFalse(query.contains("timestamp_gte: \""))
    }

    func testHostileAddressesAndInvalidTimestampBoundsAreRejectedBeforeNetworking() throws {
        let factories: [RewardOperationFactoryProtocol] = [
            SubqueryRewardOperationFactory(url: endpoint),
            ArrowsquidRewardOperationFactory(url: endpoint)
        ]
        let hostileAddresses = [
            "",
            " ",
            "stash\" }) { __schema { types { name } } } #",
            "stash\\naddress",
            "stаshAddress",
            String(repeating: "A", count: 129)
        ]

        for factory in factories {
            for address in hostileAddresses {
                try assertRejected(factory: factory, address: address)
            }

            try assertRejected(factory: factory, address: stashAddress, startTimestamp: -1)
            try assertRejected(
                factory: factory,
                address: stashAddress,
                startTimestamp: 2,
                endTimestamp: 1
            )
        }

        try assertRejected(
            factory: ArrowsquidRewardOperationFactory(url: endpoint),
            address: stashAddress,
            endTimestamp: Int64(Int32.max) + 1
        )
    }

    func testSubsquidResponseThreadsValidatorAttributionEndToEnd() throws {
        let factory = ArrowsquidRewardOperationFactory(url: endpoint)
        let operation = try networkOperation(factory: factory)
        let response = try decodeResponse(
            operation,
            json: """
            {
              "data": {
                "historyElements": [{
                  "id": "subsquid-event",
                  "blockHeight": 321,
                  "timestamp": 1700000000,
                  "address": "stashAddress",
                  "reward": {
                    "amount": "654",
                    "era": 24,
                    "stash": "stashAddress",
                    "validator": "validatorAddress"
                  }
                }]
              }
            }
            """
        )

        let rewards = try mappedRewards(response)

        XCTAssertEqual(rewards.count, 1)
        XCTAssertEqual(rewards.first?.eventId, "subsquid-event")
        XCTAssertEqual(rewards.first?.timestamp, 1_700_000_000)
        XCTAssertEqual(rewards.first?.validatorAddress, validatorAddress)
        XCTAssertEqual(rewards.first?.era, 24)
        XCTAssertEqual(rewards.first?.amount, 654)
        XCTAssertEqual(rewards.first?.isReward, true)
    }

    func testSubsquidMalformedAttributionAndForeignRowsFailClosed() throws {
        let factory = ArrowsquidRewardOperationFactory(url: endpoint)
        let operation = try networkOperation(factory: factory)
        let overflowEra = UInt64(EraIndex.max) + 1
        let response = try decodeResponse(
            operation,
            json: """
            {
              "data": {
                "historyElements": [
                  {"id":"missing-validator","blockHeight":1,"timestamp":1,"address":"stashAddress","reward":{"amount":"1","era":1,"stash":"stashAddress"}},
                  {"id":"whitespace-validator","blockHeight":2,"timestamp":2,"address":"stashAddress","reward":{"amount":"2","era":2,"stash":"stashAddress","validator":" validatorAddress "}},
                  {"id":"negative-era","blockHeight":3,"timestamp":3,"address":"stashAddress","reward":{"amount":"3","era":-1,"stash":"stashAddress","validator":"validatorAddress"}},
                  {"id":"wrong-era-type","blockHeight":4,"timestamp":4,"address":"stashAddress","reward":{"amount":"4","era":"4","stash":"stashAddress","validator":"validatorAddress"}},
                  {"id":"overflow-era","blockHeight":5,"timestamp":5,"address":"stashAddress","reward":{"amount":"5","era":\(overflowEra),"stash":"stashAddress","validator":"validatorAddress"}},
                  {"id":"wrong-validator-type","blockHeight":6,"timestamp":6,"address":"stashAddress","reward":{"amount":"6","era":6,"stash":"stashAddress","validator":7}},
                  {"id":"foreign","blockHeight":7,"timestamp":7,"address":"attackerAddress","reward":{"amount":"7","era":7,"stash":"attackerAddress","validator":"validatorAddress"}},
                  {"id":"missing-address","blockHeight":8,"timestamp":8,"address":null,"reward":{"amount":"8","era":8,"stash":"stashAddress","validator":"validatorAddress"}},
                  {"id":"mismatched-stash","blockHeight":9,"timestamp":9,"address":"stashAddress","reward":{"amount":"9","era":9,"stash":"attackerAddress","validator":"validatorAddress"}}
                ]
              }
            }
            """
        )

        let rewards = try mappedRewards(response)

        XCTAssertEqual(rewards.count, 6)
        XCTAssertEqual(rewards.map(\.amount), (1 ... 6).map { BigUInt($0) })
        XCTAssertTrue(rewards.allSatisfy { $0.validatorAddress.isEmpty && $0.era == 0 })
        XCTAssertFalse(rewards.contains {
            ["foreign", "missing-address", "mismatched-stash"].contains($0.eventId)
        })
    }

    func testMalformedRequiredRewardAmountRejectsWholeResponse() throws {
        let subqueryOperation = try networkOperation(
            factory: SubqueryRewardOperationFactory(url: endpoint)
        )
        XCTAssertThrowsError(
            try decodeResponse(
                subqueryOperation,
                json: """
                {"data":{"delegators":{"nodes":[{
                  "id":"stashAddress",
                  "delegatorHistoryElements":{"nodes":[{
                    "id":"invalid-amount",
                    "blockNumber":1,
                    "amount":-1,
                    "type":2,
                    "timestamp":"1",
                    "delegatorId":"stashAddress",
                    "collatorId":"validatorAddress",
                    "roundId":"1"
                  }]}
                }]}}}
                """
            )
        )

        let subsquidOperation = try networkOperation(
            factory: ArrowsquidRewardOperationFactory(url: endpoint)
        )

        XCTAssertThrowsError(
            try decodeResponse(
                subsquidOperation,
                json: """
                {"data":{"historyElements":[{
                  "id":"invalid-amount",
                  "blockHeight":1,
                  "timestamp":1,
                  "address":"stashAddress",
                  "reward":{"amount":"-1","era":1,"validator":"validatorAddress"}
                }]}}
                """
            )
        )
    }

    func testCanonicalRewardAmountAtMaximumSupportedWidthIsAccepted() throws {
        let amount = String(repeating: "9", count: RewardAmountParser.maximumDecimalDigits)
        let expectedAmount = try XCTUnwrap(BigUInt(amount))

        let subqueryResponse = try decodeResponse(
            try networkOperation(factory: SubqueryRewardOperationFactory(url: endpoint)),
            json: subqueryJSON(amount: amount)
        )
        let subsquidResponse = try decodeResponse(
            try networkOperation(factory: ArrowsquidRewardOperationFactory(url: endpoint)),
            json: subsquidJSON(amount: amount)
        )

        XCTAssertEqual(try mappedRewards(subqueryResponse).first?.amount, expectedAmount)
        XCTAssertEqual(try mappedRewards(subsquidResponse).first?.amount, expectedAmount)
    }

    func testNonCanonicalAndOversizedRewardAmountsAreRejectedBeforeBigUIntConstruction() throws {
        let invalidAmounts = [
            "",
            "+1",
            "-1",
            " 1",
            "1 ",
            "01",
            "1.0",
            "1e3",
            "١",
            String(repeating: "9", count: RewardAmountParser.maximumDecimalDigits + 1),
            String(repeating: "9", count: 10000)
        ]

        for amount in invalidAmounts {
            XCTAssertThrowsError(
                try decodeResponse(
                    try networkOperation(factory: SubqueryRewardOperationFactory(url: endpoint)),
                    json: subqueryJSON(amount: amount)
                )
            )
            XCTAssertThrowsError(
                try decodeResponse(
                    try networkOperation(factory: ArrowsquidRewardOperationFactory(url: endpoint)),
                    json: subsquidJSON(amount: amount)
                )
            )
        }
    }

    func testLegacyRewardItemsRemainBackwardCompatibleAndUnattributed() throws {
        let response = StaticRewardHistoryResponse(items: [
            LegacyRewardHistoryItem(
                id: "legacy",
                type: .reward,
                timestampInSeconds: "123",
                blockNumber: 1,
                amount: 99
            )
        ])

        let rewards = try mappedRewards(response)

        XCTAssertEqual(rewards.count, 1)
        XCTAssertEqual(rewards.first?.amount, 99)
        XCTAssertEqual(rewards.first?.validatorAddress, "")
        XCTAssertEqual(rewards.first?.era, 0)
    }
}

private extension RewardDataSourceTests {
    func subqueryJSON(amount: String) -> String {
        """
        {"data":{"delegators":{"nodes":[{
          "id":"stashAddress",
          "delegatorHistoryElements":{"nodes":[{
            "id":"amount-test",
            "blockNumber":1,
            "amount":"\(amount)",
            "type":2,
            "timestamp":"1",
            "delegatorId":"stashAddress",
            "collatorId":"validatorAddress",
            "roundId":"1"
          }]}
        }]}}}
        """
    }

    func subsquidJSON(amount: String) -> String {
        """
        {"data":{"historyElements":[{
          "id":"amount-test",
          "blockHeight":1,
          "timestamp":1,
          "address":"stashAddress",
          "reward":{
            "amount":"\(amount)",
            "era":1,
            "stash":"stashAddress",
            "validator":"validatorAddress"
          }
        }]}}
        """
    }

    func assertRejected(
        factory: RewardOperationFactoryProtocol,
        address: AccountAddress,
        startTimestamp: Int64? = nil,
        endTimestamp: Int64? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let operation = factory.createDelegatorRewardsOperation(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        switch try XCTUnwrap(operation.result, file: file, line: line) {
        case .success:
            XCTFail("Invalid reward query parameters were accepted", file: file, line: line)
        case let .failure(error):
            XCTAssertTrue(error is RewardHistoryRequestError, file: file, line: line)
        }
    }

    func networkOperation(
        factory: RewardOperationFactoryProtocol,
        startTimestamp: Int64? = nil,
        endTimestamp: Int64? = nil
    ) throws -> NetworkOperation<RewardHistoryResponseProtocol> {
        let operation = factory.createDelegatorRewardsOperation(
            address: stashAddress,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )
        return try XCTUnwrap(operation as? NetworkOperation<RewardHistoryResponseProtocol>)
    }

    func requestQuery(_ operation: NetworkOperation<RewardHistoryResponseProtocol>) throws -> String {
        let request = try operation.requestFactory.createRequest()
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        return try XCTUnwrap(json["query"] as? String)
    }

    func decodeResponse(
        _ operation: NetworkOperation<RewardHistoryResponseProtocol>,
        json: String
    ) throws -> RewardHistoryResponseProtocol {
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        return try operation.resultFactory.createResult(
            data: Data(json.utf8),
            response: response,
            error: nil
        ).get()
    }

    func mappedRewards(_ response: RewardHistoryResponseProtocol) throws -> [SubqueryRewardItemData] {
        let source = ParachainSubqueryRewardsSource(
            address: stashAddress,
            url: endpoint,
            operationFactory: RewardOperationFactoryStub(response: response)
        )
        let wrapper = source.fetchOperation()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get() ?? []
    }

    func mappedWeeklyRewards(_ response: RewardHistoryResponseProtocol) throws -> [SubqueryRewardItemData] {
        let source = ParachainWeaklyAnalyticsRewardSource(
            address: stashAddress,
            operationFactory: RewardOperationFactoryStub(response: response)
        )
        let wrapper = source.fetchOperation()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get() ?? []
    }
}

private enum RewardDataSourceTestError: Error {
    case unsupported
}

private final class RewardOperationFactoryStub: RewardOperationFactoryProtocol {
    private let response: RewardHistoryResponseProtocol

    init(response: RewardHistoryResponseProtocol) {
        self.response = response
    }

    func createHistoryOperation(
        address _: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) -> BaseOperation<RewardOrSlashResponse> {
        ClosureOperation { throw RewardDataSourceTestError.unsupported }
    }

    func createDelegatorRewardsOperation(
        address _: String,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol> {
        ClosureOperation { self.response }
    }

    func createAprOperation(
        for _: @escaping () throws -> [AccountId],
        dependingOn _: BaseOperation<String>
    ) -> BaseOperation<CollatorAprResponse> {
        ClosureOperation { throw RewardDataSourceTestError.unsupported }
    }

    func createLastRoundOperation() -> BaseOperation<String> {
        ClosureOperation { throw RewardDataSourceTestError.unsupported }
    }
}

private struct StaticRewardHistoryResponse: RewardHistoryResponseProtocol {
    let items: [RewardHistoryItemProtocol]

    func rewardHistory(for _: String) -> [RewardHistoryItemProtocol] {
        items
    }
}

private struct LegacyRewardHistoryItem: RewardHistoryItemProtocol {
    let id: String
    let type: SubqueryDelegationAction
    let timestampInSeconds: String
    let blockNumber: Int
    let amount: BigUInt
}
