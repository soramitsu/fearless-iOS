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
    private static var sharedEventCenter: EventCenterProtocol {
        EventCenter.shared
    }

    static let shared = NetworkIssuesCenter(eventCenter: sharedEventCenter)

    private var issuesListeners: [WeakWrapper] = []

    private var _chainsWithIssues: Set<ChainModel> = []
    private var chainsWithIssues: Set<ChainModel> {
        get {
            _chainsWithIssues
        }
        set(newValue) {
            if newValue != _chainsWithIssues {
                _chainsWithIssues = newValue
                notify()
            }
        }
    }

    private let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
        self.eventCenter.add(observer: self, dispatchIn: nil)
    }

    // MARK: - Public methods

    func addIssuesListener(
        _ listener: NetworkIssuesCenterListener,
        getExisting: Bool
    ) {
        let weakListener = WeakWrapper(target: listener)
        issuesListeners.append(weakListener)

        guard getExisting, _chainsWithIssues.isNotEmpty else { return }
        let chains = Array(_chainsWithIssues)
        (weakListener.target as? NetworkIssuesCenterListener)?.handleChainsWithIssues(chains)
    }

    func removeIssuesListener(_ listener: NetworkIssuesCenterListener) {
        issuesListeners = issuesListeners.filter { wrapper in
            guard let target = wrapper.target else {
                return false
            }

            return target !== listener
        }
    }

    func forceNotify() {
        notify()
    }

    // MARK: - Private methods

    private func handle(event: ChainReconnectingEvent) {
        let chain = event.chain
        let state = event.state

        switch state {
        case .connected:
            if chainsWithIssues.contains(chain) {
                chainsWithIssues.remove(chain)
            }
        case .notConnected:
            if !chainsWithIssues.contains(where: { $0.chainId == chain.chainId }) {
                chainsWithIssues.insert(chain)
            }
        default:
            break
        }
    }

    private func updateIssues(with attempt: Int, for chain: ChainModel) {
        if attempt > NetworkConstants.websocketReconnectAttemptsLimit {
            if !chainsWithIssues.contains(where: { $0.chainId == chain.chainId }) {
                chainsWithIssues.insert(chain)
            }
        } else {
            chainsWithIssues.remove(chain)
        }
    }

    private func notify() {
        let chains = Array(_chainsWithIssues)
        issuesListeners.forEach {
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
