import Foundation
@testable import SSFUtils
import XCTest

/// `unsubsribe(_:)` must end the subscription on the node, not only locally:
/// Substrate keeps sending updates until it receives the subscription ID it
/// assigned, through the unsubscribe method that matches the subscribe method.
final class WebSocketEngineUnsubscribeTests: XCTestCase {
    func testUnsubscribeEndsStorageSubscriptionWithItsSubscriptionId() throws {
        let fixture = NodeConnectedEngine()
        let updates = UpdateCounter()
        let id = try fixture.subscribeToBlockNumber(updates)
        waitUntil("the node assigns a subscription ID") { fixture.remoteId(of: id) == "sub-1" }
        fixture.node.produceBlock()
        waitUntil("the first block arrives") { updates.count == 1 }

        XCTAssertNoThrow(try fixture.engine.unsubsribe(id))
        XCTAssertFalse(fixture.hasSubscription(id), "the handler goes at once")

        waitUntil("the node ends the subscription") { fixture.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(fixture.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])

        fixture.node.produceBlock()
        fixture.node.produceBlock()
        fixture.settle()
        XCTAssertEqual(updates.count, 1, "no update after unsubscribing")
    }

    func testUnsubscribeBeforeTheSubscriptionIdArrivesEndsTheSubscriptionOnceItDoes() throws {
        let fixture = NodeConnectedEngine()
        fixture.node.holdsSubscribeAnswers = true
        let updates = UpdateCounter()
        let id = try fixture.subscribeToBlockNumber(updates)
        waitUntil("the subscribe request is sent") { fixture.node.requests("state_subscribeStorage").count == 1 }

        XCTAssertNoThrow(try fixture.engine.unsubsribe(id))
        XCTAssertFalse(fixture.hasSubscription(id), "the handler goes at once")
        fixture.settle()
        XCTAssertTrue(fixture.node.requests("state_unsubscribeStorage").isEmpty, "there is no ID to send yet")

        fixture.node.releaseHeldAnswers()
        waitUntil("the node ends the subscription once its ID arrives") { fixture.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(fixture.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])

        fixture.node.produceBlock()
        fixture.settle()
        XCTAssertEqual(updates.count, 0)
        XCTAssertTrue(fixture.unknownUpdates.isEmpty, "nothing is kept for an ended subscription")
    }

    func testUnsubscribeOfQueuedSubscriptionNeverSendsIt() throws {
        let fixture = NodeConnectedEngine(connected: false)
        fixture.node.acceptsConnections = false
        let updates = UpdateCounter()
        let id = try fixture.subscribeToBlockNumber(updates)
        XCTAssertEqual(fixture.pendingRequestIds, [id])

        XCTAssertNoThrow(try fixture.engine.unsubsribe(id))
        XCTAssertFalse(fixture.hasSubscription(id))
        XCTAssertTrue(fixture.pendingRequestIds.isEmpty, "a request never sent is dropped")

        fixture.node.emit(.connected([:]))
        waitUntil("the engine connects") { fixture.isConnected }
        fixture.settle()
        XCTAssertTrue(fixture.node.requests.isEmpty)
        XCTAssertTrue(fixture.node.liveSubscriptions.isEmpty)
    }

    func testUnsubscribeUsesTheUnsubscribeMethodOfEachSubscriptionMethod() throws {
        let fixture = NodeConnectedEngine()
        let methods = [
            ("chain_subscribeFinalizedHeads", "chain_unsubscribeFinalizedHeads"),
            ("chain_subscribeNewHeads", "chain_unsubscribeNewHeads"),
            ("state_subscribeRuntimeVersion", "state_unsubscribeRuntimeVersion")
        ]

        for (subscribeMethod, unsubscribeMethod) in methods {
            let updates = UpdateCounter()
            let id = try fixture.engine.subscribe(
                subscribeMethod,
                params: [String](),
                updateClosure: updates.record,
                failureClosure: { _, _ in }
            )
            waitUntil("\(subscribeMethod) gets a subscription ID") { fixture.remoteId(of: id) != nil }
            let remoteId = try XCTUnwrap(fixture.remoteId(of: id))

            XCTAssertNoThrow(try fixture.engine.unsubsribe(id))

            waitUntil("the node ends \(subscribeMethod)") { !fixture.node.liveSubscriptions.contains(remoteId) }
            XCTAssertEqual(fixture.node.requests(unsubscribeMethod).map(\.stringParams), [[remoteId]])
        }

        XCTAssertTrue(fixture.node.requests("state_unsubscribeStorage").isEmpty)
        fixture.node.produceBlock()
        fixture.settle()
        XCTAssertTrue(fixture.node.liveSubscriptions.isEmpty)
    }

    func testUnsubscribeOfWatcherWithoutSubscribeRequestRemovesItLocally() throws {
        // SubstrateTransactionObserver watches extrinsic status updates this way.
        let fixture = NodeConnectedEngine()
        let updates = UpdateCounter()
        let id = fixture.engine.generateRequestId()
        let watcher = JSONRPCSubscription(
            requestId: id,
            requestData: Data(),
            requestOptions: JSONRPCOptions(resendOnReconnect: true),
            updateClosure: updates.record,
            failureClosure: { _, _ in }
        )
        watcher.remoteId = "0xwatched"
        fixture.engine.addSubscription(watcher)
        fixture.node.notify(subscription: "0xwatched", method: "author_extrinsicUpdate")
        waitUntil("the watcher receives updates") { updates.count == 1 }

        XCTAssertNoThrow(try fixture.engine.unsubsribe(id))
        XCTAssertFalse(fixture.hasSubscription(id))

        fixture.node.notify(subscription: "0xwatched", method: "author_extrinsicUpdate")
        fixture.settle()
        XCTAssertEqual(updates.count, 1)
        XCTAssertTrue(fixture.node.requests.isEmpty, "no subscribe method to derive an unsubscribe method from")
    }

    func testSocketDropBeforeTheSubscriptionIdArrivesDoesNotSubscribeAgain() throws {
        let fixture = NodeConnectedEngine()
        fixture.node.holdsSubscribeAnswers = true
        let updates = UpdateCounter()
        let id = try fixture.subscribeToBlockNumber(updates)
        waitUntil("the subscribe request is sent") { fixture.node.requests("state_subscribeStorage").count == 1 }
        XCTAssertNoThrow(try fixture.engine.unsubsribe(id))

        fixture.node.holdsSubscribeAnswers = false
        fixture.node.dropConnection()
        waitUntil("the engine reconnects") { fixture.node.connectionAttempts == 2 && fixture.isConnected }
        fixture.settle()

        XCTAssertEqual(
            fixture.node.requests("state_subscribeStorage").count,
            1,
            "an unsubscribed request is not sent again"
        )
        XCTAssertTrue(fixture.node.liveSubscriptions.isEmpty)
        fixture.node.produceBlock()
        fixture.settle()
        XCTAssertEqual(updates.count, 0)
    }

    func testUpdatesSentBeforeTheNodeHandlesTheUnsubscribeAreDropped() throws {
        let fixture = NodeConnectedEngine()
        let updates = UpdateCounter()
        let id = try fixture.subscribeToBlockNumber(updates)
        waitUntil("the node assigns a subscription ID") { fixture.remoteId(of: id) == "sub-1" }
        fixture.node.holdsUnsubscribeAnswers = true

        XCTAssertNoThrow(try fixture.engine.unsubsribe(id))
        waitUntil("the unsubscribe request is sent") { fixture.node.requests("state_unsubscribeStorage").count == 1 }
        // A block the node announced before it read the unsubscribe request.
        fixture.node.notify(subscription: "sub-1")
        fixture.settle()
        XCTAssertEqual(updates.count, 0)

        fixture.node.releaseHeldAnswers()
        fixture.settle()
        XCTAssertTrue(fixture.unknownUpdates.isEmpty, "nothing is kept for an ended subscription")
    }
}
