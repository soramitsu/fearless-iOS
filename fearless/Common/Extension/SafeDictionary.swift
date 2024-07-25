import Foundation

final class SafeDictionary<V: Hashable, T>: Collection {
    private(set) var dictionary: [V: T]
    private let concurrentQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearless.safe.dict.queue.\(UUID().uuidString)",
        attributes: .concurrent
    )

    var keys: Dictionary<V, T>.Keys {
        concurrentQueue.sync {
            self.dictionary.keys
        }
    }

    var values: Dictionary<V, T>.Values {
        concurrentQueue.sync {
            self.dictionary.values
        }
    }

    var startIndex: Dictionary<V, T>.Index {
        concurrentQueue.sync {
            self.dictionary.startIndex
        }
    }

    var endIndex: Dictionary<V, T>.Index {
        concurrentQueue.sync {
            self.dictionary.endIndex
        }
    }

    init(dict: [V: T] = [V: T]()) {
        dictionary = dict
    }

    func replace(dict: [V: T]) {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary = dict
        }
    }

    func index(after i: Dictionary<V, T>.Index) -> Dictionary<V, T>.Index {
        concurrentQueue.sync {
            self.dictionary.index(after: i)
        }
    }

    func removeValue(forKey key: V) {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary.removeValue(forKey: key)
        }
    }

    func removeAll() {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary.removeAll()
        }
    }

    subscript(key: V) -> T? {
        set(newValue) {
            concurrentQueue.async(flags: .barrier) { [weak self] in
                self?.dictionary[key] = newValue
            }
        }
        get {
            concurrentQueue.sync {
                self.dictionary[key]
            }
        }
    }

    subscript(index: Dictionary<V, T>.Index) -> Dictionary<V, T>.Element {
        concurrentQueue.sync {
            self.dictionary[index]
        }
    }
}
