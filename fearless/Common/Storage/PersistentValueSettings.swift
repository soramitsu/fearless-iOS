import Foundation

class PersistentValueSettings<T> {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    private let mutex = NSLock()

    var internalValue: T?

    var value: T! {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return internalValue
    }

    func performSetup(completionClosure _: @escaping (Result<T?, Error>) -> Void) {
        // Function must be implemented in subclass
    }

    func performSave(value _: T, completionClosure _: @escaping (Result<T, Error>) -> Void) {
        // Function must be implemented in subclass
    }

    func setup(
        runningCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<T?, Error>
        ) -> Void
    ) {
        mutex.lock()

        performSetup { result in
            if case let .success(newValue) = result {
                self.internalValue = newValue
            }

            self.mutex.unlock()

            queue.async {
                completionClosure(result)
            }
        }
    }

    func save(
        value: T,
        runningCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<T, Error>) -> Void
    ) {
        mutex.lock()

        performSave(value: value) { result in
            if case let .success(newValue) = result {
                self.internalValue = newValue
            }

            self.mutex.unlock()

            queue.async {
                completionClosure(result)
            }
        }
    }
}
