import Foundation

public struct ViewModelObserverWrapper<Observer> where Observer: AnyObject {
    weak var observer: Observer?

    init(observer: Observer) {
        self.observer = observer
    }
}

public final class ViewModelObserverContainer<Observer> where Observer: AnyObject {
    private(set) var observers: [ViewModelObserverWrapper<Observer>] = []

    public func add(observer: Observer) {
        observers = observers.filter { $0.observer != nil }

        guard !observers.contains(where: { $0.observer === observer }) else {
            return
        }

        observers.append(ViewModelObserverWrapper(observer: observer))
    }

    public func remove(observer: Observer) {
        observers = observers.filter { $0.observer != nil && $0.observer !== observer }
    }
}
