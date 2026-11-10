import XCTest
@testable import fearless

/// The swap screen resubscribes to SORA blocks on every pair change. Each
/// `unsubscribe()` must end the previous subscription on the node, or every
/// block delivers one more update per earlier pair.
final class PolkaswapRemoteSubscriptionServiceTests: XCTestCase {
    func testUnsubscribeEndsTheBlockSubscriptionOnTheNode() {
        let connection = ScriptedSubstrateConnection()
        let service = PolkaswapRemoteSubscriptionService(connection: connection.engine, logger: Logger.shared)
        let updates = UpdateTally()

        service.subscribeToBlocks { _ in updates.add() }
        connection.waitUntil("the node confirms the subscription") { connection.deliveredRemoteIds == ["sub-1"] }
        connection.node.produceBlock()
        connection.waitUntil("the first block arrives") { updates.count == 1 }

        service.unsubscribe()

        connection.waitUntil("the node ends the subscription") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(connection.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)

        connection.node.produceBlock()
        connection.node.produceBlock()
        connection.settle()
        XCTAssertEqual(updates.count, 1, "no block arrives after unsubscribing")
    }

    func testResubscribingOnEveryPairChangeKeepsOneSubscription() {
        let connection = ScriptedSubstrateConnection()
        let service = PolkaswapRemoteSubscriptionService(connection: connection.engine, logger: Logger.shared)
        var updates: [UpdateTally] = []

        // PolkaswapAdjustmentInteractor.subscribeOnBlocks() on five pair changes.
        for pair in 1 ... 5 {
            let tally = UpdateTally()
            updates.append(tally)
            service.unsubscribe()
            service.subscribeToBlocks { _ in tally.add() }
            connection.waitUntil("pair \(pair) has the only subscription") {
                connection.node.liveSubscriptions == ["sub-\(pair)"] && connection.deliveredRemoteIds == ["sub-\(pair)"]
            }
        }

        connection.node.produceBlock()
        connection.waitUntil("the latest pair receives the block") { updates.last?.count == 1 }
        connection.settle()
        XCTAssertEqual(updates.map(\.count), [0, 0, 0, 0, 1])
    }

    func testUnsubscribeAlsoEndsSubscriptionsFromEarlierCalls() {
        let connection = ScriptedSubstrateConnection()
        let service = PolkaswapRemoteSubscriptionService(connection: connection.engine, logger: Logger.shared)

        service.subscribeToBlocks { _ in }
        service.subscribeToBlocks { _ in }
        connection.waitUntil("both subscriptions are confirmed") { connection.deliveredRemoteIds.count == 2 }

        service.unsubscribe()

        connection.waitUntil("the node ends both") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)
    }
}

final class UpdateTally {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func add() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
