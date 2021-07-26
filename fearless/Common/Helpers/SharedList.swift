import Foundation

class SharedList<T: Equatable> {
    private var store: [T]

    init(items: [T]) {
        store = items
    }

    var count: Int { store.count }

    var items: [T] { store }

    func item(at index: Int) -> T { store[index] }

    func contains(_ item: T) -> Bool { store.contains(item) }

    public func set(_ items: [T]) {
        store = items
    }

    public func append(_ item: T) {
        store.append(item)
    }

    public func append(contentsOf items: [T]) {
        store.append(contentsOf: items)
    }

    public func remove(_ item: T) {
        store.removeAll { $0 == item }
    }

    @discardableResult
    public func remove(at index: Int) -> T {
        store.remove(at: index)
    }

    public func firstIndex(of item: T) -> Int? {
        store.firstIndex(of: item)
    }
}
