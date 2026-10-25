import Foundation
import Reachability

public protocol ReachabilityListenerDelegate: AnyObject {
    func didChangeReachability(by manager: ReachabilityManagerProtocol)
}

public protocol ReachabilityManagerProtocol {
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

public final class ReachabilityManager {
    public static let shared: ReachabilityManager? = ReachabilityManager()

    private var _listeners: [ReachabilityListenerWrapper] = []
    private var listeners: [ReachabilityListenerWrapper] {
        get {
            lock.concurrentlyRead {
                return _listeners
            }
        }
        set {
            lock.exclusivelyWrite { [unowned self] in
                self._listeners = newValue
            }
        }
    }
    private var reachability: Reachability
    private let lock = ReaderWriterLock()

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
    public var isReachable: Bool {
        reachability.connection != .unavailable
    }

    public func add(listener: ReachabilityListenerDelegate) throws {
        if listeners.isEmpty {
            try reachability.startNotifier()
        }

        listeners = listeners.filter { $0.listener != nil }

        if !listeners.contains(where: { $0.listener === listener }) {
            let wrapper = ReachabilityListenerWrapper(listener: listener)
            listeners.append(wrapper)
        }
    }

    public func remove(listener: ReachabilityListenerDelegate) {
        listeners = listeners.filter { $0.listener != nil && $0.listener !== listener }

        if listeners.isEmpty {
            reachability.stopNotifier()
        }
    }
}
