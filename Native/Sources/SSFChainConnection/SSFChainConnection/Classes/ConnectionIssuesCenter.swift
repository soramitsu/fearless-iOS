import Foundation
import SSFModels
import SSFUtils

public protocol ConnectionIssuesCenterListener: AnyObject {
    func handleChainsWithIssues(_ chains: [ChainModel.Id])
}

public protocol NetworkIssuesCenterProtocol {
    func addIssuesListener(
        _ listener: ConnectionIssuesCenterListener,
        getExisting: Bool
    )
    func removeIssuesListener(_ listener: ConnectionIssuesCenterListener)
    func forceNotify()
}

public final class NetworkIssuesCenterImpl: NetworkIssuesCenterProtocol {
    static let shared = NetworkIssuesCenterImpl()

    private var issuesListeners: [WeakWrapper] = []

    private var _chainsWithIssues: Set<ChainModel.Id> = []
    private var chainsWithIssues: Set<ChainModel.Id> {
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

    private init() {}

    // MARK: - Public methods

    public func addIssuesListener(
        _ listener: ConnectionIssuesCenterListener,
        getExisting: Bool
    ) {
        let weakListener = WeakWrapper(target: listener)
        issuesListeners.append(weakListener)

        guard getExisting, !_chainsWithIssues.isEmpty else { return }
        let chains = Array(_chainsWithIssues)
        (weakListener.target as? ConnectionIssuesCenterListener)?.handleChainsWithIssues(chains)
    }

    public func removeIssuesListener(_ listener: ConnectionIssuesCenterListener) {
        issuesListeners = issuesListeners.filter { $0 !== listener }
    }

    public func forceNotify() {
        notify()
    }

    // MARK: - Internal methods

    func handle(
        chain: ChainModel.Id,
        state: SSFUtils.WebSocketEngine.State
    ) {
        switch state {
        case .connected:
            if chainsWithIssues.contains(chain) {
                chainsWithIssues.remove(chain)
            }
        case .notConnected:
            chainsWithIssues.insert(chain)
        default:
            break
        }
    }

    // MARK: - Private methods

    private func updateIssues(with attempt: Int, for chain: ChainModel.Id) {
        if attempt > NetworkConstants.websocketReconnectAttemptsLimit {
            chainsWithIssues.insert(chain)
        } else {
            chainsWithIssues.remove(chain)
        }
    }

    private func notify() {
        let chains = Array(_chainsWithIssues)
        for issuesListener in issuesListeners {
            (issuesListener.target as? ConnectionIssuesCenterListener)?
                .handleChainsWithIssues(chains)
        }
    }
}
