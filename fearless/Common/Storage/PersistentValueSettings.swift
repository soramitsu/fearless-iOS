import Foundation

enum PersistentValueSettingsError: Error {
    case missingValue
}

class PersistentValueSettings<T> {
    private struct PendingSave {
        let value: T
        let completion: (Result<T, Error>) -> Void
    }

    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    private let mutex = NSLock()

    var internalValue: T?
    private var committedValue: T?
    private var pendingSaves: [PendingSave] = []
    private var isPerformingSave = false
    private var actionsWaitingForSaves: [() -> Void] = []

    var value: T? {
        mutex.lock()

        defer {
            mutex.unlock()
        }
        return internalValue
    }

    var hasValue: Bool { value != nil }

    @discardableResult
    func applySetupResult(
        _ result: Result<T?, Error>,
        when shouldApply: () -> Bool,
        commit: () -> Void = {}
    ) -> Bool {
        applySetupResultAtomically(result) { applyValue in
            guard shouldApply() else {
                return false
            }

            applyValue()
            commit()

            return true
        }
    }

    /// Executes `commitIfCurrent` with `mutex` held. The supplied `applyValue`
    /// closure updates both the visible and committed values and must be called
    /// exactly once when `commitIfCurrent` returns `true`.
    @discardableResult
    func applySetupResultAtomically(
        _ result: Result<T?, Error>,
        commitIfCurrent: (_ applyValue: () -> Void) -> Bool
    ) -> Bool {
        mutex.lock()

        guard
            pendingSaves.isEmpty,
            !isPerformingSave
        else {
            mutex.unlock()
            return false
        }

        let applyValue = {
            if case let .success(newValue) = result {
                self.internalValue = newValue
                self.committedValue = newValue
            }
        }
        let didCommit = commitIfCurrent(applyValue)

        mutex.unlock()

        return didCommit
    }

    func applySetupResult(_ result: Result<T?, Error>) {
        applySetupResult(result, when: { true })
    }

    /// Called with `mutex` held immediately before the save is registered.
    /// Implementations must not re-enter `PersistentValueSettings`.
    func prepareForSaveInvocation() {}

    func performAfterPendingSaves(_ action: @escaping () -> Void) {
        mutex.lock()
        let shouldPerformImmediately = pendingSaves.isEmpty && !isPerformingSave
        if !shouldPerformImmediately {
            actionsWaitingForSaves.append(action)
        }
        mutex.unlock()

        if shouldPerformImmediately {
            action()
        }
    }

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
        performAfterPendingSaves {
            self.performSetup { result in
                self.applySetupResult(result)

                if let closure = completionClosure {
                    dispatchInQueueWhenPossible(queue) {
                        closure(result)
                    }
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
        prepareForSaveInvocation()
        internalValue = value
        pendingSaves.append(
            PendingSave(value: value) { result in
                if let completionClosure {
                    dispatchInQueueWhenPossible(queue) {
                        completionClosure(result)
                    }
                }
            }
        )
        let shouldStartSave = !isPerformingSave
        if shouldStartSave {
            isPerformingSave = true
        }
        mutex.unlock()

        if shouldStartSave {
            performNextSave()
        }
    }

    private func performNextSave() {
        mutex.lock()
        guard let pendingSave = pendingSaves.first else {
            isPerformingSave = false
            mutex.unlock()
            return
        }
        mutex.unlock()

        performSave(value: pendingSave.value) { result in
            self.completeCurrentSave(result)
        }
    }

    private func completeCurrentSave(_ result: Result<T, Error>) {
        mutex.lock()
        guard !pendingSaves.isEmpty else {
            isPerformingSave = false
            mutex.unlock()
            return
        }

        let completedSave = pendingSaves.removeFirst()
        if case let .success(newValue) = result {
            committedValue = newValue
        }

        internalValue = pendingSaves.last?.value ?? committedValue
        let hasNextSave = !pendingSaves.isEmpty
        let waitingActions = hasNextSave ? [] : actionsWaitingForSaves
        if !hasNextSave {
            actionsWaitingForSaves.removeAll()
        }
        if !hasNextSave {
            isPerformingSave = false
        }
        mutex.unlock()

        completedSave.completion(result)

        if hasNextSave {
            performNextSave()
        } else {
            waitingActions.forEach { $0() }
        }
    }

    func save(value: T) {
        save(value: value, runningCompletionIn: nil, completionClosure: nil)
    }
}
