import Foundation

final class EventCenter {
    static let shared = EventCenter()

    struct ObserverWrapper {
        weak var observer: EventVisitorProtocol?
        var dispatchQueue: DispatchQueue?
    }

    private let syncQueue: DispatchQueue

    private var wrappers: [ObserverWrapper] = []

    init(syncQueue: DispatchQueue? = nil) {
        self.syncQueue = syncQueue ?? DispatchQueue(label: "co.jp.soramitsu.fearless.event.center")
    }
}

extension EventCenter: EventCenterProtocol {
    func notify(with event: EventProtocol) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil }

            for wrapper in self.wrappers {
                guard let observer = wrapper.observer else {
                    continue
                }

                if let queue = wrapper.dispatchQueue {
                    queue.async {
                        event.accept(visitor: observer)
                    }
                } else {
                    event.accept(visitor: observer)
                }
            }
        }
    }

    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil }

            if !self.wrappers.contains(where: { $0.observer === observer }) {
                self.wrappers.append(ObserverWrapper(observer: observer, dispatchQueue: queue))
            }
        }
    }

    func remove(observer: EventVisitorProtocol) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil && $0.observer !== observer }
        }
    }
}
