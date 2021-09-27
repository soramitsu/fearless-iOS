import Foundation

enum PersistentValueSettingsError: Error {
    case missingValue
}

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

    var hasValue: Bool { value != nil }

    func performSetup(completionClosure _: @escaping (Result<T?, Error>) -> Void) {
        fatalError("Function must be implemented in subclass")
    }

    func performSave(value _: T, completionClosure _: @escaping (Result<T, Error>) -> Void) {
        fatalError("Function must be implemented in subclass")
    }

    func setup(
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<T?, Error>) -> Void)?
    ) {
        mutex.lock()

        performSetup { result in
            if case let .success(newValue) = result {
                self.internalValue = newValue
            }

            self.mutex.unlock()

            if let closure = completionClosure {
                dispatchInQueueWhenPossible(queue) {
                    closure(result)
                }
            }
        }
    }

    func setup() {
        setup(runningCompletionIn: nil, completionClosure: nil)
    }

    func save(
        value: T,
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<T, Error>) -> Void)?
    ) {
        mutex.lock()

        performSave(value: value) { result in
            if case let .success(newValue) = result {
                self.internalValue = newValue
            }

            self.mutex.unlock()

            if let closure = completionClosure {
                dispatchInQueueWhenPossible(queue) {
                    closure(result)
                }
            }
        }
    }

    func save(value: T) {
        save(value: value, runningCompletionIn: nil, completionClosure: nil)
    }
}
