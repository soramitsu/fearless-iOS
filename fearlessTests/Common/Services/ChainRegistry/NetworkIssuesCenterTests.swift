import XCTest
import SSFModels
import SSFUtils
@testable import fearless

final class NetworkIssuesCenterTests: XCTestCase {
    func testNotify_whenChainReconnects_thenUsesInjectedEventCenter() {
        let eventCenter = NetworkIssuesEventCenterSpy()
        let center = NetworkIssuesCenter(eventCenter: eventCenter)
        let listener = NetworkIssuesCenterListenerSpy()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)

        center.addIssuesListener(listener, getExisting: false)

        eventCenter.notify(with: ChainReconnectingEvent(chain: chain, state: .notConnected))
        eventCenter.notify(with: ChainReconnectingEvent(chain: chain, state: .connected))

        XCTAssertEqual(listener.receivedChainIds, [[chain.chainId], []])
    }

    func testAddIssuesListener_whenGetExistingTrue_thenReplaysCurrentIssues() {
        let eventCenter = NetworkIssuesEventCenterSpy()
        let center = NetworkIssuesCenter(eventCenter: eventCenter)
        let firstListener = NetworkIssuesCenterListenerSpy()
        let replayedListener = NetworkIssuesCenterListenerSpy()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)

        center.addIssuesListener(firstListener, getExisting: false)
        eventCenter.notify(with: ChainReconnectingEvent(chain: chain, state: .notConnected))

        center.addIssuesListener(replayedListener, getExisting: true)

        XCTAssertEqual(replayedListener.receivedChainIds, [[chain.chainId]])
    }

    func testRemoveIssuesListener_whenListenerRemoved_thenStopsSendingUpdates() {
        let eventCenter = NetworkIssuesEventCenterSpy()
        let center = NetworkIssuesCenter(eventCenter: eventCenter)
        let listener = NetworkIssuesCenterListenerSpy()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)

        center.addIssuesListener(listener, getExisting: false)
        center.removeIssuesListener(listener)
        eventCenter.notify(with: ChainReconnectingEvent(chain: chain, state: .notConnected))

        XCTAssertTrue(listener.receivedChainIds.isEmpty)
    }
}

private final class NetworkIssuesEventCenterSpy: EventCenterProtocol {
    private var observers: [EventVisitorProtocol] = []

    func notify(with event: EventProtocol) {
        observers.forEach { event.accept(visitor: $0) }
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        observers.append(observer)
    }

    func remove(observer: EventVisitorProtocol) {
        observers = observers.filter { $0 !== observer }
    }
}

private final class NetworkIssuesCenterListenerSpy: NetworkIssuesCenterListener {
    private(set) var receivedChainIds: [[ChainModel.Id]] = []

    func handleChainsWithIssues(_ chains: [ChainModel]) {
        receivedChainIds.append(chains.map(\.chainId).sorted())
    }
}
