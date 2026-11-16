import BigInt
import Foundation
import SSFUtils
import XCTest
@testable import fearless

final class CovGRewardModelsTests: XCTestCase {
    func testRewardItemDataReadsSubqueryJSONAndRejectsIncompleteNodes() throws {
        let json = try JSONDecoder().decode(JSON.self, from: Data(#"""
        {"id":"event-1","timestamp":"100","address":"stash","reward":{"validator":"validator","isReward":false,"era":5,"amount":"53"}}
        """#.utf8))
        let item = try XCTUnwrap(SubqueryRewardItemData(from: json))
        XCTAssertEqual(item.eventId, "event-1")
        XCTAssertEqual(item.timestamp, 100)
        XCTAssertEqual(item.validatorAddress, "validator")
        XCTAssertEqual(item.stashAddress, "stash")
        XCTAssertEqual(item.era, 5)
        XCTAssertEqual(item.amount, 53)
        XCTAssertFalse(item.isReward)
        let incomplete = try JSONDecoder().decode(JSON.self, from: Data(#"{"id":"event-2","timestamp":"bad"}"#.utf8))
        XCTAssertNil(SubqueryRewardItemData(from: incomplete))
    }

    func testRewardItemDataMapsHistoryItemsWithAndWithoutAttribution() {
        let reward = CovGRewardHistoryItem(id: "r", type: .reward, timestampInSeconds: "200", blockNumber: 1, amount: 7)
        let mapped = SubqueryRewardItemData(rewardHistoryItem: reward, stashAddress: "stash")
        XCTAssertEqual(mapped?.eventId, "r")
        XCTAssertEqual(mapped?.timestamp, 200)
        XCTAssertEqual(mapped?.validatorAddress, "")
        XCTAssertEqual(mapped?.era, 0)
        XCTAssertEqual(mapped?.amount, 7)
        XCTAssertEqual(mapped?.isReward, true)
        let invalid = CovGRewardHistoryItem(id: "x", type: .reward, timestampInSeconds: "later", blockNumber: 1, amount: 7)
        XCTAssertNil(SubqueryRewardItemData(rewardHistoryItem: invalid, stashAddress: "stash"))
    }

    func testEventPhasesAndExtrinsicStatusesDecodeEveryShape() throws {
        let records = try JSONDecoder().decode([EventRecord].self, from: Data(#"""
        [{"phase":["ApplyExtrinsic","3"],"event":["Balances",["Deposit",["0x01","5"]]]},
         {"phase":["Finalization",null],"event":["System",["Remarked",[]]]},
         {"phase":["Initialization",null],"event":["System",["NewAccount",[]]]}]
        """#.utf8))
        XCTAssertEqual(records.map(\.extrinsicIndex), [3, nil, nil])
        XCTAssertEqual(records.first?.event.section, "Balances")
        XCTAssertEqual(records.first?.event.method, "Deposit")
        XCTAssertThrowsError(try JSONDecoder().decode(Phase.self, from: Data(#"["Unknown",null]"#.utf8)))
        let statuses = try JSONDecoder().decode([ExtrinsicStatus].self, from: Data(#"""
        ["ready",{"broadcast":["peer"]},{"inBlock":"0x01"},{"finalized":"0x02"}]
        """#.utf8))
        XCTAssertEqual(statuses.count, 4)
        if case let .broadcast(peers) = statuses[1] { XCTAssertEqual(peers, ["peer"]) } else { XCTFail("Expected broadcast") }
        if case let .inBlock(hash) = statuses[2] { XCTAssertEqual(hash, "0x01") } else { XCTFail("Expected inBlock") }
        if case let .finalized(hash) = statuses[3] { XCTAssertEqual(hash, "0x02") } else { XCTFail("Expected finalized") }
        for json in [#""future""#, #"{"retracted":"0x03"}"#, #"{"broadcast":[1]}"#, "{}"] {
            XCTAssertThrowsError(try JSONDecoder().decode(ExtrinsicStatus.self, from: Data(json.utf8)), json)
        }
    }
}

private struct CovGRewardHistoryItem: RewardHistoryItemProtocol {
    let id: String
    let type: SubqueryDelegationAction
    let timestampInSeconds: String
    let blockNumber: Int
    let amount: BigUInt
}
