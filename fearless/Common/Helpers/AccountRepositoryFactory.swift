import Foundation
import RobinHood

protocol AccountRepositoryFactoryProtocol {
    func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel>

    func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel>

    func createAsyncMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AsyncAnyRepository<MetaAccountModel>
}

final class AccountRepositoryFactory: AccountRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        AnyDataProviderRepository(
            createTolerantRepository(
                filter: filter,
                sortDescriptors: sortDescriptors,
                project: \.wallet,
                makeUpdate: {
                    MetaAccountSelectionModel(
                        identifier: $0.identifier,
                        wallet: $0,
                        isSelected: false,
                        order: ManagedMetaAccountModel.noOrder,
                        updatesWalletPayload: true,
                        updatesSelection: false
                    )
                }
            )
        )
    }

    func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        AnyDataProviderRepository(
            createTolerantRepository(
                filter: filter,
                sortDescriptors: sortDescriptors,
                project: { projection in
                    projection.wallet.map {
                        ManagedMetaAccountModel(
                            info: $0,
                            isSelected: projection.isSelected,
                            order: projection.order
                        )
                    }
                },
                makeUpdate: {
                    MetaAccountSelectionModel(
                        identifier: $0.identifier,
                        wallet: $0.info,
                        isSelected: $0.isSelected,
                        order: $0.order,
                        updatesWalletPayload: true
                    )
                }
            )
        )
    }

    func createAsyncMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AsyncAnyRepository<MetaAccountModel> {
        let repository = createMetaAccountRepository(
            for: filter,
            sortDescriptors: sortDescriptors
        )

        return AsyncAnyRepository(
            AsyncOperationBackedRepository(repository: repository)
        )
    }

    private func createTolerantRepository<Model: Identifiable>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        project: @escaping (MetaAccountSelectionModel) -> Model?,
        makeUpdate: @escaping (Model) -> MetaAccountSelectionModel
    ) -> TolerantMetaAccountRepository<Model> {
        let supportedWalletFilter = NSPredicate(
            format: "%K != nil AND %K != nil",
            #keyPath(CDMetaAccount.substrateAccountId),
            #keyPath(CDMetaAccount.substratePublicKey)
        )
        let readFilter = filter.map {
            NSCompoundPredicate(
                andPredicateWithSubpredicates: [$0, supportedWalletFilter]
            )
        } ?? supportedWalletFilter
        let readRepository = storageFacade.createRepository(
            filter: readFilter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )
        let writeRepository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )
        let deleteRepository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
        )

        return TolerantMetaAccountRepository(
            readRepository: readRepository,
            writeRepository: writeRepository,
            deleteRepository: deleteRepository,
            project: project,
            makeUpdate: makeUpdate
        )
    }
}

extension AccountRepositoryFactory {
    static func createRepository(
        for storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
    }
}

enum TolerantMetaAccountRepositoryError: LocalizedError, Equatable {
    case invalidSliceRequest

    var errorDescription: String? {
        switch self {
        case .invalidSliceRequest:
            return "The repository slice request has an unsupported shape or range"
        }
    }
}

/// RobinHood keeps `RepositorySliceRequest` fields internal. Decode its reflected value through
/// one validated boundary so paging can happen after damaged rows have been projected out.
/// Any dependency shape change fails closed instead of silently returning the wrong page.
struct ValidatedRepositorySlice {
    typealias ReflectedField = (label: String?, value: Any)

    let offset: Int
    let count: Int
    let reversed: Bool

    var isEmpty: Bool {
        count == 0
    }

    init(request: RepositorySliceRequest) throws {
        let mirror = Mirror(reflecting: request)
        guard mirror.displayStyle == .struct else {
            throw TolerantMetaAccountRepositoryError.invalidSliceRequest
        }

        try self.init(reflectedFields: Array(mirror.children))
    }

    init(reflectedFields: [ReflectedField]) throws {
        guard reflectedFields.count == 3 else {
            throw TolerantMetaAccountRepositoryError.invalidSliceRequest
        }

        var values: [String: Any] = [:]
        let expectedLabels = Set(["offset", "count", "reversed"])

        for field in reflectedFields {
            guard
                let label = field.label,
                expectedLabels.contains(label),
                values.updateValue(field.value, forKey: label) == nil
            else {
                throw TolerantMetaAccountRepositoryError.invalidSliceRequest
            }
        }

        guard
            Set(values.keys) == expectedLabels,
            let offset = values["offset"] as? Int,
            let count = values["count"] as? Int,
            let reversed = values["reversed"] as? Bool,
            offset >= 0,
            count >= 0
        else {
            throw TolerantMetaAccountRepositoryError.invalidSliceRequest
        }

        self.offset = offset
        self.count = count
        self.reversed = reversed
    }
}

private final class TolerantMetaAccountRepository<Model: Identifiable>: DataProviderRepositoryProtocol {
    fileprivate typealias ProjectionRepository = CoreDataRepository<
        MetaAccountSelectionModel,
        CDMetaAccount
    >

    private let readRepository: ProjectionRepository
    private let writeRepository: ProjectionRepository
    private let deleteRepository: ProjectionRepository
    private let project: (MetaAccountSelectionModel) -> Model?
    private let makeUpdate: (Model) -> MetaAccountSelectionModel
    private let operationQueue = OperationQueue()

    fileprivate init(
        readRepository: ProjectionRepository,
        writeRepository: ProjectionRepository,
        deleteRepository: ProjectionRepository,
        project: @escaping (MetaAccountSelectionModel) -> Model?,
        makeUpdate: @escaping (Model) -> MetaAccountSelectionModel
    ) {
        self.readRepository = readRepository
        self.writeRepository = writeRepository
        self.deleteRepository = deleteRepository
        self.project = project
        self.makeUpdate = makeUpdate
    }

    func fetchOperation(
        by modelIdsClosure: @escaping () throws -> [String],
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation {
            let identifiers = Set(try modelIdsClosure())
            let projections = try self.fetchAllVisibleProjections(options: options)

            return try self.projectModels(
                projections.filter { identifiers.contains($0.identifier) }
            )
        }
    }

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation {
            let identifier = try modelIdClosure()
            let projections = try self.fetchAllVisibleProjections(options: options)

            return try self.projectModels(
                projections.filter { $0.identifier == identifier }
            ).first
        }
    }

    func fetchAllOperation(
        with options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation {
            try self.projectModels(
                self.fetchAllVisibleProjections(options: options)
            )
        }
    }

    func fetchOperation(
        by request: RepositorySliceRequest,
        options: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation {
            let slice = try ValidatedRepositorySlice(request: request)
            let visibleModels = try self.projectModels(
                self.fetchAllVisibleProjections(options: options)
            )
            let orderedModels = slice.reversed
                ? Array(visibleModels.reversed())
                : visibleModels

            guard
                !slice.isEmpty,
                slice.offset < orderedModels.count
            else {
                return []
            }

            return Array(
                orderedModels
                    .dropFirst(slice.offset)
                    .prefix(slice.count)
            )
        }
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation {
            let models = try updateModelsBlock()
            let requestedDeleteIds = try deleteIdsBlock()
            try self.save(models: models, requestedDeleteIds: requestedDeleteIds)
        }
    }

    func saveBatchOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        saveOperation(updateModelsBlock, deleteIdsBlock)
    }

    func replaceOperation(
        _ newModelsBlock: @escaping () throws -> [Model]
    ) -> BaseOperation<Void> {
        ClosureOperation {
            let models = try newModelsBlock()
            try self.validateUniqueIdentifiers(models.map(\.identifier))
            try self.validateNoUnsupportedCollisions(for: models.map(\.identifier))

            let existingOperation = self.readRepository.fetchAllOperation(
                with: RepositoryFetchOptions(
                    includesProperties: true,
                    includesSubentities: true
                )
            )
            let existing = try self.execute(existingOperation)
            let replacementIds = Set(models.map(\.identifier))
            let supportedIdsToDelete: [String] = existing.compactMap { projection -> String? in
                guard
                    projection.wallet != nil,
                    !replacementIds.contains(projection.identifier)
                else {
                    return nil
                }

                return projection.identifier
            }
            try self.validateUnambiguousStoredIdentifiers(
                supportedIdsToDelete
            )

            try self.persist(
                models: models,
                deleteIds: supportedIdsToDelete
            )
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation {
            let operation = self.readRepository.fetchAllOperation(
                with: RepositoryFetchOptions(
                    includesProperties: true,
                    includesSubentities: true
                )
            )

            return try self.projectModels(self.execute(operation)).count
        }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {
            let operation = self.deleteRepository.deleteAllOperation()
            _ = try self.execute(operation)
        }
    }

    private func save(
        models: [Model],
        requestedDeleteIds: [String]
    ) throws {
        try validateUniqueIdentifiers(models.map(\.identifier))
        try validateNoUnsupportedCollisions(for: models.map(\.identifier))
        try validateUnambiguousStoredIdentifiers(requestedDeleteIds)

        let requestedDeleteIdSet = Set(requestedDeleteIds)
        let visibleProjections = requestedDeleteIdSet.isEmpty
            ? []
            : try fetchAllVisibleProjections(
                options: RepositoryFetchOptions(
                    includesProperties: true,
                    includesSubentities: true
                )
            )
        let safeDeleteIds: [String] = visibleProjections.compactMap { projection -> String? in
            guard
                projection.wallet != nil,
                requestedDeleteIdSet.contains(projection.identifier)
            else {
                return nil
            }

            return projection.identifier
        }

        try persist(models: models, deleteIds: safeDeleteIds)
    }

    private func validateUniqueIdentifiers(_ identifiers: [String]) throws {
        guard Set(identifiers).count == identifiers.count else {
            throw SelectedWalletSettingsError.duplicateWalletIdentifier
        }
    }

    private func projectModels(
        _ projections: [MetaAccountSelectionModel]
    ) throws -> [Model] {
        let models = projections.compactMap(project)
        try validateUniqueIdentifiers(models.map(\.identifier))
        return models
    }

    private func validateNoUnsupportedCollisions(
        for identifiers: [String]
    ) throws {
        guard !identifiers.isEmpty else {
            return
        }

        let identifierSet = Set(identifiers)
        let operation = writeRepository.fetchAllOperation(
            with: RepositoryFetchOptions(
                includesProperties: true,
                includesSubentities: true
            )
        )
        let existing = try execute(operation).filter {
            identifierSet.contains($0.identifier)
        }

        guard Set(existing.map(\.identifier)).count == existing.count else {
            throw SelectedWalletSettingsError.duplicateWalletIdentifier
        }

        guard !existing.contains(where: { $0.wallet == nil }) else {
            throw SelectedWalletSettingsError.unsupportedWalletIdentifierConflict
        }
    }

    private func validateUnambiguousStoredIdentifiers(
        _ identifiers: [String]
    ) throws {
        let identifierSet = Set(identifiers)
        guard !identifierSet.isEmpty else {
            return
        }

        let operation = writeRepository.fetchAllOperation(
            with: RepositoryFetchOptions(
                includesProperties: true,
                includesSubentities: true
            )
        )
        let matchingProjections = try execute(operation).filter {
            identifierSet.contains($0.identifier)
        }
        let projectionsByIdentifier = Dictionary(
            grouping: matchingProjections,
            by: \.identifier
        )

        guard projectionsByIdentifier.values.allSatisfy({ $0.count <= 1 }) else {
            // CoreDataRepository deletes the first matching entity. Duplicate identifiers
            // would therefore make deletion depend on persistent-store fetch order and could
            // destroy a quarantined or unsupported wallet instead of its healthy sibling.
            throw SelectedWalletSettingsError.duplicateWalletIdentifier
        }
    }

    private func fetchAllVisibleProjections(
        options: RepositoryFetchOptions
    ) throws -> [MetaAccountSelectionModel] {
        let operation = readRepository.fetchAllOperation(with: options)
        return try execute(operation)
    }

    private func persist(
        models: [Model],
        deleteIds: [String]
    ) throws {
        let updates = models.map(makeUpdate)
        let operation = writeRepository.saveOperation(
            { updates },
            { deleteIds }
        )

        _ = try execute(operation)
    }

    private func execute<Result>(
        _ operation: BaseOperation<Result>
    ) throws -> Result {
        operationQueue.addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }
}

private final class AsyncOperationBackedRepository<Model: Identifiable>: AsyncCoreDataRepository {
    private let repository: AnyDataProviderRepository<Model>
    private let operationQueue = OperationQueue()

    init(repository: AnyDataProviderRepository<Model>) {
        self.repository = repository
    }

    func fetch(
        by modelIds: [String],
        options: RepositoryFetchOptions
    ) async throws -> [Model] {
        try await execute(
            repository.fetchOperation(
                by: { modelIds },
                options: options
            )
        )
    }

    func fetch(
        by modelId: String,
        options: RepositoryFetchOptions
    ) async throws -> Model? {
        try await execute(
            repository.fetchOperation(
                by: { modelId },
                options: options
            )
        )
    }

    func fetchAll(
        with options: RepositoryFetchOptions
    ) async throws -> [Model] {
        try await execute(repository.fetchAllOperation(with: options))
    }

    func save(models: [Model], deleteIds: [String]) async {
        let operation = repository.saveOperation(
            { models },
            { deleteIds }
        )

        await withCheckedContinuation { continuation in
            operation.completionBlock = {
                continuation.resume()
            }
            operationQueue.addOperation(operation)
        }
    }

    private func execute<Result>(
        _ operation: BaseOperation<Result>
    ) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            operation.completionBlock = {
                do {
                    continuation.resume(
                        returning: try operation.extractNoCancellableResultData()
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            operationQueue.addOperation(operation)
        }
    }
}
