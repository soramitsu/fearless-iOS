import Foundation
import SSFModels

protocol NetworkIssuesCenterListener: AnyObject {
    func handleChainsWithIssues(_ chains: [ChainModel])
}

protocol NetworkIssuesCenterProtocol {
    func addIssuesListener(
        _ listener: NetworkIssuesCenterListener,
        getExisting: Bool
    )
    func removeIssuesListener(_ listener: NetworkIssuesCenterListener)
    func forceNotify()
}

final class NetworkIssuesCenter: NetworkIssuesCenterProtocol {
    static let shared = NetworkIssuesCenter(eventCenter: EventCenter.shared)

    // Listeners are added while screens are built and notified from the event
    // queue, so the list and the set are only touched under this lock. Listeners
    // are called after it is released: one may add or remove a listener in reply.
    private let lock = NSLock()
    private var issuesListeners: [WeakWrapper] = []
    private var chainsWithIssues: Set<ChainModel> = []

    private let eventCenter: EventCenter

    private init(eventCenter: EventCenter) {
        self.eventCenter = eventCenter
        self.eventCenter.add(observer: self, dispatchIn: nil)
    }

    // MARK: - Public methods

    func addIssuesListener(
        _ listener: NetworkIssuesCenterListener,
        getExisting: Bool
    ) {
        lock.lock()
        issuesListeners.append(WeakWrapper(target: listener))
        let chains = Array(chainsWithIssues)
        lock.unlock()

        guard getExisting, chains.isNotEmpty else { return }
        listener.handleChainsWithIssues(chains)
    }

    func removeIssuesListener(_ listener: NetworkIssuesCenterListener) {
        lock.lock()
        issuesListeners = issuesListeners.filter { $0.target !== listener }
        lock.unlock()
    }

    func forceNotify() {
        notify()
    }

    // MARK: - Private methods

    private func handle(event: ChainReconnectingEvent) {
        let chain = event.chain

        lock.lock()
        var updated = chainsWithIssues

        switch event.state {
        case .connected:
            updated.remove(chain)
        case .notConnected, .notReachable:
            if !updated.contains(where: { $0.chainId == chain.chainId }) {
                updated.insert(chain)
            }
        default:
            break
        }

        let changed = updated != chainsWithIssues
        chainsWithIssues = updated
        lock.unlock()

        if changed {
            notify()
        }
    }

    private func notify() {
        lock.lock()
        let chains = Array(chainsWithIssues)
        let listeners = issuesListeners
        lock.unlock()

        listeners.forEach {
            ($0.target as? NetworkIssuesCenterListener)?.handleChainsWithIssues(chains)
        }
    }
}

// MARK: - EventVisitorProtocol

extension NetworkIssuesCenter: EventVisitorProtocol {
    func processChainReconnecting(event: ChainReconnectingEvent) {
        handle(event: event)
    }
}
