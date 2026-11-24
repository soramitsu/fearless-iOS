import XCTest
@testable import fearless

final class SubstrateTransactionObserverTests: XCTestCase {
    func testReleasingTheObserverRemovesItsStatusWatchersFromTheEngine() async throws {
        let connection = ScriptedSubstrateConnection()
        var observer: SubstrateTransactionObserver? = SubstrateTransactionObserver(engine: connection.engine)

        _ = try await observer?.subscribe(transactionHash: "0xfirst")
        _ = try await observer?.subscribe(transactionHash: "0xsecond")
        XCTAssertEqual(connection.deliveredRemoteIds, ["0xfirst", "0xsecond"])

        observer = nil

        XCTAssertEqual(connection.registeredSubscriptionCount, 0, "a released observer leaves no watcher behind")
        connection.settle()
        XCTAssertTrue(connection.node.requests.isEmpty, "these watchers have no subscribe request to end")
    }
}
