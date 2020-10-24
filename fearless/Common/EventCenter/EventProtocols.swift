import Foundation

protocol EventProtocol {
    func accept(visitor: EventVisitorProtocol)
}

protocol EventCenterProtocol {
    func notify(with event: EventProtocol)
    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)
    func remove(observer: EventVisitorProtocol)
}

extension EventCenterProtocol {
    func add(observer: EventVisitorProtocol) {
        add(observer: observer, dispatchIn: nil)
    }
}
