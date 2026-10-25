import Foundation

enum PersistentValueSettingsError: Error {
    case missingValue
}

open class PersistentValueSettings<T> {
    public let storageFacade: StorageFacadeProtocol

    public init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    private let mutex = NSLock()

    public var internalValue: T?

    public var value: T? {
        mutex.lock()

        defer {
            mutex.unlock()
        }
        return internalValue
    }

    var hasValue: Bool { value != nil }

    open func performSetup(completionClosure _: @escaping (Result<T?, Error>) -> Void) {
        fatalError("Function must be implemented in subclass")
    }

    open func performSave(value _: T, completionClosure _: @escaping (Result<T, Error>) -> Void) {
        fatalError("Function must be implemented in subclass")
    }

    public func setup(
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

    public func setup() {
        setup(runningCompletionIn: nil, completionClosure: nil)
    }

    public func save(
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

    public func save(value: T) {
        save(value: value, runningCompletionIn: nil, completionClosure: nil)
    }
}

func dispatchInQueueWhenPossible(_ queue: DispatchQueue?, block: @escaping () -> Void) {
    if let queue = queue {
        queue.async(execute: block)
    } else {
        block()
    }
}
