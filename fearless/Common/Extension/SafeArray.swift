import Foundation

final class SafeArray<T>: Collection {
    private var array: [T]
    private let concurrentQueue = DispatchQueue(
        label: "jp.co.soramitsu.fearless.safe.array.queue.\(UUID().uuidString)",
        attributes: .concurrent
    )

    var startIndex: Array<T>.Index {
        concurrentQueue.sync {
            self.array.startIndex
        }
    }

    var endIndex: Array<T>.Index {
        concurrentQueue.sync {
            self.array.endIndex
        }
    }

    init(array: [T] = [T]()) {
        self.array = array
    }

    func replace(array: [T]) {
        concurrentQueue.async(flags: .barrier) {
            self.array = array
        }
    }

    func append(_ newElement: T) {
        concurrentQueue.async(flags: .barrier) {
            self.array.append(newElement)
        }
    }

    func index(after i: Int) -> Int {
        concurrentQueue.sync {
            self.array.index(after: i)
        }
    }
    
    func remove(where predicate: @escaping (Element) -> Bool) {
        concurrentQueue.async(flags: .barrier) {
            while let index = self.array.firstIndex(where: predicate) {
                self.array.remove(at: index)
            }
        }
    }

    subscript(position: Int) -> T {
        concurrentQueue.sync {
            self.array[position]
        }
    }
}
