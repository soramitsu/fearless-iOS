import Foundation
import Reachability

protocol ReachabilityListenerDelegate: class {
    func didChangeReachability(by manager: ReachabilityManagerProtocol)
}

protocol ReachabilityManagerProtocol {
    var isReachable: Bool { get }

    func add(listener: ReachabilityListenerDelegate) throws
    func remove(listener: ReachabilityListenerDelegate)
}

fileprivate final class ReachabilityListenerWrapper {
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

        reachability.whenReachable = { [weak self] (reachability) in
            if let strongSelf = self {
                self?.listeners.forEach { $0.listener?.didChangeReachability(by: strongSelf) }
            }
        }

        reachability.whenUnreachable = { [weak self] (reachability) in
            if let strongSelf = self {
                self?.listeners.forEach { $0.listener?.didChangeReachability(by: strongSelf) }
            }
        }
    }
}

extension ReachabilityManager: ReachabilityManagerProtocol {

    var isReachable: Bool {
        return reachability.connection != .unavailable
    }

    func add(listener: ReachabilityListenerDelegate) throws {
        if listeners.count == 0 {
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

        if listeners.count == 0 {
            reachability.stopNotifier()
        }
    }
}
