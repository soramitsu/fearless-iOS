import Foundation
import RobinHood

enum SelectedWalletStoreState: Equatable {
    case unresolved
    case empty
    case ready
    case unsupportedOnly
    case unavailable
}

enum SelectedWalletSettingsError: LocalizedError {
    case duplicateWalletIdentifier
    case unsupportedWalletIdentifierConflict

    var errorDescription: String? {
        switch self {
        case .duplicateWalletIdentifier:
            return "The wallet store contains duplicate identifiers"
        case .unsupportedWalletIdentifierConflict:
            return "A supported wallet conflicts with an unsupported stored wallet"
        }
    }
}

final class SelectedWalletSettings: PersistentValueSettings<MetaAccountModel> {
    private typealias SetupOutcome = (
        selectedWallet: MetaAccountModel?,
        repairedAccounts: [MetaAccountSelectionModel],
        storeState: SelectedWalletStoreState
    )

    static let shared = SelectedWalletSettings(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.persistentQueue
    )

    let operationQueue: OperationQueue
    private let storeStateLock = NSLock()
    private var internalStoreState = SelectedWalletStoreState.unresolved
    private let setupGenerationLock = NSLock()
    private var setupGeneration = UUID()
    private let savePreparationHook: (() -> Void)?
    private let setupPreparationHook: (() -> Void)?
    private let setupCommitHook: (() -> Void)?

    var storeState: SelectedWalletStoreState {
        storeStateLock.lock()
        defer { storeStateLock.unlock() }

        return internalStoreState
    }

    init(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        savePreparationHook: (() -> Void)? = nil,
        setupPreparationHook: (() -> Void)? = nil,
        setupCommitHook: (() -> Void)? = nil
    ) {
        self.operationQueue = operationQueue
        self.savePreparationHook = savePreparationHook
        self.setupPreparationHook = setupPreparationHook
        self.setupCommitHook = setupCommitHook

        super.init(storageFacade: storageFacade)
    }

    override func prepareForSaveInvocation() {
        _ = replaceSetupGeneration()
        savePreparationHook?()
    }

    override func setup(
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<MetaAccountModel?, Error>) -> Void)?
    ) {
        let generation = replaceSetupGeneration()
        setupPreparationHook?()

        performAfterPendingSaves {
            self.performSetupOutcome(generation: generation) { result in
                let publicResult = result.map(\.selectedWallet)
                self.commitSetupOutcomeIfCurrent(result, generation: generation)

                if let completionClosure {
                    dispatchInQueueWhenPossible(queue) {
                        completionClosure(publicResult)
                    }
                }
            }
        }
    }

    override func performSetup(completionClosure: @escaping (Result<MetaAccountModel?, Error>) -> Void) {
        performSetupOutcome(generation: nil) { result in
            completionClosure(result.map(\.selectedWallet))
        }
    }

    private func performSetupOutcome(
        generation: UUID?,
        completionClosure: @escaping (Result<SetupOutcome, Error>) -> Void
    ) {
        let selectionMapper = MetaAccountSelectionMapper()
        let repository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(selectionMapper)
        )
        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let fetchOperation = repository.fetchAllOperation(with: options)
        let selectionOperation: BaseOperation<SetupOutcome> = ClosureOperation {
            let accounts = try fetchOperation.extractNoCancellableResultData()

            guard Set(accounts.map(\.identifier)).count == accounts.count else {
                throw SelectedWalletSettingsError.duplicateWalletIdentifier
            }

            guard !accounts.isEmpty else {
                return (nil, [], .empty)
            }

            let supportedAccounts = accounts.filter { $0.wallet != nil }
            guard !supportedAccounts.isEmpty else {
                let containsStructurallyValidUnsupportedWallet = accounts.contains {
                    $0.recordState == .unsupported
                }
                let state: SelectedWalletStoreState =
                    containsStructurallyValidUnsupportedWallet
                        ? .unsupportedOnly
                        : .unavailable

                return (nil, [], state)
            }

            let selectedSupportedAccounts = supportedAccounts.filter(\.isSelected)
            let selectionPool = selectedSupportedAccounts.isEmpty
                ? supportedAccounts
                : selectedSupportedAccounts
            guard
                let selectedAccount = selectionPool.min(by: Self.precedesForSelection),
                let selectedWallet = selectedAccount.wallet
            else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            let repairedAccounts: [MetaAccountSelectionModel] = accounts.compactMap { account in
                guard account.recordState.allowsStoredRecordUpdates else {
                    return nil
                }

                let shouldBeSelected = account.identifier == selectedAccount.identifier
                return account.isSelected == shouldBeSelected
                    ? nil
                    : account.replacingSelection(shouldBeSelected)
            }

            return (selectedWallet, repairedAccounts, .ready)
        }
        let repairOperation: BaseOperation<Void> = ClosureOperation {
            let repairedAccounts = try selectionOperation
                .extractNoCancellableResultData()
                .repairedAccounts

            guard !repairedAccounts.isEmpty else {
                return
            }

            let repair = {
                let saveOperation = repository.saveOperation(
                    { repairedAccounts },
                    { [] }
                )
                let queue = OperationQueue()
                queue.addOperations([saveOperation], waitUntilFinished: true)
                _ = try saveOperation.extractNoCancellableResultData()
            }

            if let generation {
                try self.performRepairIfCurrent(
                    generation: generation,
                    repair: repair
                )
            } else {
                try repair()
            }
        }

        selectionOperation.addDependency(fetchOperation)
        repairOperation.addDependency(selectionOperation)

        repairOperation.completionBlock = {
            do {
                _ = try repairOperation.extractNoCancellableResultData()
                let result = try selectionOperation.extractNoCancellableResultData()
                completionClosure(.success(result))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations(
            [fetchOperation, selectionOperation, repairOperation],
            waitUntilFinished: false
        )
    }

    private func replaceSetupGeneration() -> UUID {
        let generation = UUID()

        setupGenerationLock.lock()
        setupGeneration = generation
        setupGenerationLock.unlock()

        return generation
    }

    private func commitSetupOutcomeIfCurrent(
        _ result: Result<SetupOutcome, Error>,
        generation: UUID
    ) {
        let publicResult = result.map(\.selectedWallet)
        let storeState: SelectedWalletStoreState
        switch result {
        case let .success(outcome):
            storeState = outcome.storeState
        case .failure:
            storeState = .unavailable
        }

        applySetupResultAtomically(publicResult) { applyValue in
            self.setupGenerationLock.lock()
            defer { self.setupGenerationLock.unlock() }

            guard self.setupGeneration == generation else {
                return false
            }

            applyValue()
            self.setupCommitHook?()
            self.updateStoreState(storeState)

            return true
        }
    }

    private func performRepairIfCurrent(
        generation: UUID,
        repair: () throws -> Void
    ) throws {
        setupGenerationLock.lock()
        defer { setupGenerationLock.unlock() }

        guard setupGeneration == generation else {
            return
        }

        try repair()
    }

    override func performSave(
        value: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        let selectionMapper = MetaAccountSelectionMapper()
        let repository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(selectionMapper)
        )
        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let allAccountsOperation = repository.fetchAllOperation(with: options)

        let saveOperation = repository.saveOperation({
            let existingAccounts = try allAccountsOperation.extractNoCancellableResultData()

            guard Set(existingAccounts.map(\.identifier)).count == existingAccounts.count else {
                throw SelectedWalletSettingsError.duplicateWalletIdentifier
            }

            let existingTarget = existingAccounts.first {
                $0.identifier == value.identifier
            }

            if let existingTarget, existingTarget.wallet == nil {
                throw SelectedWalletSettingsError.unsupportedWalletIdentifierConflict
            }

            var accountsToSave: [MetaAccountSelectionModel] = existingAccounts.compactMap { account in
                guard
                    account.recordState.allowsStoredRecordUpdates,
                    account.identifier != value.identifier,
                    account.isSelected
                else {
                    return nil
                }

                return account.replacingSelection(false)
            }

            accountsToSave.append(
                MetaAccountSelectionModel(
                    identifier: value.identifier,
                    wallet: value,
                    isSelected: true,
                    order: existingTarget?.order ?? ManagedMetaAccountModel.noOrder,
                    updatesWalletPayload: true
                )
            )

            return accountsToSave
        }, { [] })

        saveOperation.addDependency(allAccountsOperation)

        saveOperation.completionBlock = { [weak self] in
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                self?.updateStoreState(.ready)
                completionClosure(.success(value))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations([allAccountsOperation, saveOperation], waitUntilFinished: false)
    }

    private static func precedesForSelection(
        _ lhs: MetaAccountSelectionModel,
        _ rhs: MetaAccountSelectionModel
    ) -> Bool {
        let lhsOrder = lhs.order == ManagedMetaAccountModel.noOrder ? UInt32.max : lhs.order
        let rhsOrder = rhs.order == ManagedMetaAccountModel.noOrder ? UInt32.max : rhs.order

        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }

        return lhs.identifier < rhs.identifier
    }

    private func updateStoreState(_ state: SelectedWalletStoreState) {
        storeStateLock.lock()
        internalStoreState = state
        storeStateLock.unlock()
    }
}
