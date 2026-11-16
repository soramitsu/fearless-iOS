import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovGGiantsquidHistoryTests: XCTestCase {
    private let filters: [WalletTransactionHistoryFilter] = [
        .init(type: .transfer, selected: true), .init(type: .reward, selected: true), .init(type: .other, selected: true)
    ]

    private let responseJSON = #"""
    {"data":{"transfers":[{"id":"response","transfer":{"id":"transfer","amount":"3000000000000","from":{"id":"owner"},
    "to":{"id":"peer"},"success":false,"timestamp":"2024-01-01T00:00:00.000000+0000","extrinsicHash":"hash","blockNumber":7}}],
    "stakingRewards":[{"id":"reward","amount":"1000000000000","era":5,"accountId":"owner","validator":"validator",
    "timestamp":1704067200000,"extrinsicHash":"reward-hash","blockNumber":3}],
    "bonds":[{"id":"bond","accountId":"owner","amount":"2000000000000","blockNumber":4,"extrinsicHash":"bond-hash","success":true,
    "timestamp":"2024-01-01T00:00:00.000000+0000","type":"Bond"}],
    "slashes":[{"id":"slash","accountId":"owner","amount":"500000000000","blockNumber":5,"era":6,"timestamp":"2024-01-02T00:00:00.000000+0000"}]}}
    """#

    func testEveryGiantsquidHistoryKindIsMappedInSourceOrder() throws {
        let repository = InMemoryDataProviderRepository<TransactionHistoryItem>()
        let factory = GiantsquidHistoryOperationFactory(txStorage: AnyDataProviderRepository(repository))
        let chain = try CovGOperationFixtures.chain()
        let wrapper = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: "owner", filters: filters, pagination: Pagination(count: 10)
        )
        let network = try CovGOperationFixtures.network(wrapper, as: GiantsquidResponseData.self)
        try CovGOperationFixtures.respond(network, json: responseJSON)
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(page.transactions.map(\.transactionId), ["transfer", "reward", "bond", "slash"])
        XCTAssertEqual(page.transactions[0].status, .rejected)
        XCTAssertEqual(page.transactions[0].amount.decimalValue, 3)
        XCTAssertEqual(page.transactions[1].type, TransactionType.reward.rawValue)
        XCTAssertEqual(page.transactions[1].amount.decimalValue, 1)
        XCTAssertEqual(page.transactions[2].type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(page.transactions[2].amount.decimalValue, 2)
        XCTAssertEqual(page.transactions[3].type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(page.transactions[3].amount.decimalValue, Decimal(string: "0.5"))
        XCTAssertNil(page.context)
    }

    func testRewardDecodingFallsBackToNumericTimestampAndExposesRewardFields() throws {
        let response = try JSONDecoder().decode(GiantsquidResponse.self, from: Data(responseJSON.utf8))
        XCTAssertEqual(response.data.history.map(\.identifier), ["transfer", "reward", "bond", "slash"])
        XCTAssertEqual(response.data.history.map(\.label), [.transfers, .rewards, .extrinsics, .extrinsics])
        XCTAssertEqual(response.data.data.count, 1)
        let reward = try XCTUnwrap(response.data.stakingRewards?.first)
        XCTAssertEqual(reward.timestamp, "1704067200000")
        XCTAssertEqual(reward.timestampInSeconds, 0)
        XCTAssertEqual(reward.address, "owner")
        XCTAssertEqual(reward.stash, "owner")
        XCTAssertEqual(reward.eventIdx, "reward")
        XCTAssertEqual(reward.era, 5)
        XCTAssertEqual(reward.validator, "validator")
        XCTAssertEqual(reward.blockNumber, 3)
        XCTAssertTrue(reward.isReward)
        XCTAssertNil(reward.assetId)
        XCTAssertNotNil(reward.rewardInfo)
        XCTAssertEqual(reward.itemBlockNumber, 0)
        XCTAssertEqual(reward.itemExtrinsicIndex, 0)
        let bond = try XCTUnwrap(response.data.bonds?.first)
        XCTAssertEqual(bond.itemTimestamp, 1_704_067_200)
        XCTAssertEqual(bond.itemBlockNumber, 0)
        XCTAssertEqual(bond.itemExtrinsicIndex, 0)
        let slash = try XCTUnwrap(response.data.slashes?.first)
        XCTAssertEqual(slash.itemTimestamp, 1_704_153_600)
        XCTAssertEqual(slash.itemBlockNumber, 0)
        XCTAssertEqual(slash.itemExtrinsicIndex, 0)
        let transfer = try XCTUnwrap(response.data.transfers?.first?.transfer)
        XCTAssertEqual(transfer.itemTimestamp, 1_704_067_200)
        XCTAssertEqual(transfer.itemBlockNumber, 0)
        XCTAssertEqual(transfer.itemExtrinsicIndex, 0)
        XCTAssertEqual(transfer.to?.id, "peer")
    }

    func testIdentifiersFallBackToExtrinsicHashThenTimestampAndAmount() throws {
        let rewards = try JSONDecoder().decode([GiantsquidReward].self, from: Data(#"""
        [{"amount":"7","timestamp":"t1","extrinsicHash":"hash"},{"amount":"8","timestamp":"t2"}]
        """#.utf8))
        XCTAssertEqual(rewards.map(\.identifier), ["hash", "t28"])
        XCTAssertEqual(rewards.map(\.address), ["", ""])
        XCTAssertNil(rewards[0].era)
        let transfers = try JSONDecoder().decode([GiantsquidTransfer].self, from: Data(#"""
        [{"amount":"9","timestamp":"t3","extrinsicHash":"transfer-hash"},{"amount":"10","timestamp":"t4"}]
        """#.utf8))
        XCTAssertEqual(transfers.map(\.identifier), ["transfer-hash", "t410"])
        XCTAssertThrowsError(try JSONDecoder().decode(GiantsquidReward.self, from: Data(#"{"amount":"1","timestamp":true}"#.utf8)))
    }

    func testFirstPageMergesRemoteGiantsquidItemsWithPendingLocalTransfer() throws {
        let repository = InMemoryDataProviderRepository<TransactionHistoryItem>()
        let pending = TransactionHistoryItem(
            sender: "owner", receiver: "peer", status: .pending, txHash: "pending-hash", timestamp: 9,
            fee: "0", blockNumber: nil, txIndex: nil, callPath: .transfer, call: nil
        )
        try CovGOperationFixtures.run(repository.saveOperation({ [pending] }, { [] }))
        let factory = GiantsquidHistoryOperationFactory(txStorage: AnyDataProviderRepository(repository))
        let chain = try CovGOperationFixtures.chain()
        let wrapper = factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: chain, address: "owner", filters: filters, pagination: Pagination(count: 10)
        )
        let network = try CovGOperationFixtures.network(wrapper, as: GiantsquidResponseData.self)
        try CovGOperationFixtures.respond(network, json: responseJSON)
        let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
        XCTAssertEqual(Set(page.transactions.map(\.transactionId)), ["pending-hash", "transfer", "reward", "bond", "slash"])
    }
}
