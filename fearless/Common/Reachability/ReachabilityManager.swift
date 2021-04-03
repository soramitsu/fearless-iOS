import Foundation
import Reachability

protocol ReachabilityListenerDelegate: AnyObject {
    func didChangeReachability(by manager: ReachabilityManagerProtocol)
}

protocol ReachabilityManagerProtocol {
    var isReachable: Bool { get }

    func add(listener: ReachabilityListenerDelegate) throws
    func remove(listener: ReachabilityListenerDelegate)
}

private final class ReachabilityListenerWrapper {
    weak var listener: ReachabilityListenerDelegate?

    init(listener: ReachabilityListenerDelegate) {
        self.listener = listener
    }
}

final class ReachabilityManager {
    static let shared: ReachabilityManager? = ReachabilityManager()

    private var listeners: [ReachabilityListenerWrapper] = []
    private var reachability: Reachability

    private init?() {
        guard let newReachability = try? Reachability() else {
            return nil
        }

        reachability = newReachability

        reachability.whenReachable = { [weak self] _ in
            if let strongSelf = self {
                self?.listeners.forEach { $0.listener?.didChangeReachability(by: strongSelf) }
            }
        }

        reachability.whenUnreachable = { [weak self] _ in
            if let strongSelf = self {
                self?.listeners.forEach { $0.listener?.didChangeReachability(by: strongSelf) }
            }
        }
    }
}

extension ReachabilityManager: ReachabilityManagerProtocol {
    var isReachable: Bool {
        reachability.connection != .unavailable
    }

    func add(listener: ReachabilityListenerDelegate) throws {
        if listeners.isEmpty {
            try reachability.startNotifier()
        }

        listeners = listeners.filter { $0.listener != nil }

        if !listeners.contains(where: { $0.listener === listener }) {
            let wrapper = ReachabilityListenerWrapper(listener: listener)
            listeners.append(wrapper)
        }
    }

    func remove(listener: ReachabilityListenerDelegate) {
        listeners = listeners.filter { $0.listener != nil && $0.listener !== listener }

        if listeners.isEmpty {
            reachability.stopNotifier()
        }
    }
}
