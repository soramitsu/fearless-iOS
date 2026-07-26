import CoreData
import Foundation
import IrohaCrypto
import RobinHood
#if canImport(SSFAccountManagmentStorage)
    import SSFAccountManagmentStorage
#endif

protocol AccountProviderFactoryProtocol {
    var operationManager: OperationManagerProtocol { get }

    func createStreambleProvider(
        for accountId: AccountId
    ) -> StreamableProvider<MetaAccountModel>
}

final class AccountProviderFactory: AccountProviderFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    init(
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
    }

    func createStreambleProvider(
        for accountId: AccountId
    ) -> StreamableProvider<MetaAccountModel> {
        let mapper = MetaAccountMapper()

        let filter = NSPredicate.filterAccountItemByAccountId(accountId)
        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: filter, sortDescriptors: [])

        let hexAccountId = accountId.toHex()
        let observable = TolerantMetaAccountContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { [hexAccountId] metaAccount in
                self.matches(metaAccount: metaAccount, accountId: hexAccountId)
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider<MetaAccountModel>(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )
    }

    /// Builds the same observable managed-wallet stream as `StorageFacade.createStreamableProvider`,
    /// while using the tolerant repository for its initial fetch and paging.
    ///
    /// The observable deliberately watches every wallet change. Consumers such as banners use an
    /// `isSelected` repository filter but still need to observe a wallet becoming unselected.
    func createManagedMetaAccountProvider(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> StreamableProvider<ManagedMetaAccountModel> {
        let mapper = ManagedMetaAccountMapper()
        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createManagedMetaAccountRepository(
                for: filter,
                sortDescriptors: sortDescriptors
            )
        let observable = TolerantMetaAccountContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { _ in true }
        )

        observable.start { [weak self] error in
            if let error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider<ManagedMetaAccountModel>(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )
    }

    private func matches(metaAccount: CDMetaAccount, accountId: String) -> Bool {
        if metaAccount.substrateAccountId == accountId || metaAccount.ethereumAddress == accountId {
            return true
        }

        guard let chainAccounts = metaAccount.chainAccounts else {
            return false
        }

        return chainAccounts.contains { chainEntity in
            guard let chainAccount = chainEntity as? CDChainAccount else {
                return false
            }

            return chainAccount.accountId == accountId
        }
    }
}

/// A Core Data observable that quarantines malformed wallet rows for their full lifecycle.
///
/// RobinHood's generic observable drops mapper failures for inserts and updates, but emits deletes
/// directly from the raw identifier. A corrupt row that duplicates a healthy wallet identifier can
/// therefore remove the healthy item from a stream when that corrupt row is deleted. Tracking
/// successfully mapped rows by object ID makes deletes unambiguous. Aggregating every notification
/// by persistent identifier also makes same-identifier object handoffs independent of Core Data's
/// unordered notification sets.
final class TolerantMetaAccountContextObservable<Model: Identifiable>:
    DataProviderRepositoryObservable {
    private struct MappedObject {
        let objectId: NSManagedObjectID
        let model: Model?
    }

    private enum ObjectMutation {
        case replace(Model?)
        case delete
    }

    private struct InFlightDelivery {
        let observerIdentifier: ObjectIdentifier
        let identifiers: Set<String>
    }

    private let service: CoreDataServiceProtocol
    private let mapper: AnyCoreDataMapper<Model, CDMetaAccount>
    private let predicate: (CDMetaAccount) -> Bool
    private let processingQueue: DispatchQueue

    private var observers: [RepositoryObserver<Model>] = []
    private var trackedModels: [NSManagedObjectID: Model] = [:]
    private var pendingReconciliationIdentifiers = Set<String>()
    // StreamableProvider can queue source callbacks behind its user-observer teardown.
    // Reconcile identifiers whose serial source deliveries were not acknowledged first.
    private var inFlightDeliveries: [UUID: InFlightDelivery] = [:]
    private var notificationToken: NSObjectProtocol?

    init(
        service: CoreDataServiceProtocol,
        mapper: AnyCoreDataMapper<Model, CDMetaAccount>,
        predicate: @escaping (CDMetaAccount) -> Bool,
        processingQueue: DispatchQueue? = nil
    ) {
        self.service = service
        self.mapper = mapper
        self.predicate = predicate
        self.processingQueue = processingQueue ?? DispatchQueue(
            label: "jp.co.fearless.wallet-observable.\(UUID().uuidString)",
            qos: .utility
        )
    }

    func start(completionBlock: @escaping (Error?) -> Void) {
        service.performAsync { [weak self] optionalContext, optionalError in
            guard let self else {
                completionBlock(optionalError)
                return
            }
            guard optionalError == nil, let context = optionalContext else {
                completionBlock(optionalError)
                return
            }

            let token = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: context,
                queue: nil
            ) { [weak self] notification in
                self?.didReceive(notification: notification)
            }
            self.notificationToken = token

            do {
                let request = NSFetchRequest<CDMetaAccount>(
                    entityName: String(describing: CDMetaAccount.self)
                )
                request.includesSubentities = false
                let initialModels = try context.fetch(request).compactMap {
                    self.mappedObject(for: $0)
                }

                self.processingQueue.async {
                    self.trackedModels = Dictionary(
                        uniqueKeysWithValues: initialModels.compactMap {
                            guard let model = $0.model else {
                                return nil
                            }

                            return ($0.objectId, model)
                        }
                    )
                    self.pendingReconciliationIdentifiers.removeAll()
                    self.inFlightDeliveries.removeAll()
                    completionBlock(nil)
                }
            } catch {
                NotificationCenter.default.removeObserver(token)
                self.notificationToken = nil
                completionBlock(error)
            }
        }
    }

    func stop(completionBlock: @escaping (Error?) -> Void) {
        service.performAsync { [weak self] _, optionalError in
            guard let self else {
                completionBlock(optionalError)
                return
            }

            if let notificationToken = self.notificationToken {
                NotificationCenter.default.removeObserver(notificationToken)
                self.notificationToken = nil
            }

            self.processingQueue.async {
                self.trackedModels.removeAll()
                self.pendingReconciliationIdentifiers.removeAll()
                self.inFlightDeliveries.removeAll()
                completionBlock(optionalError)
            }
        }
    }

    func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void
    ) {
        processingQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            guard !self.observers.contains(where: { $0.observer === observer }) else {
                return
            }

            self.observers.append(
                RepositoryObserver(
                    observer: observer,
                    queue: queue,
                    updateBlock: updateBlock
                )
            )

            let reconciliationChanges = self.reconciliationChanges(
                for: self.pendingReconciliationIdentifiers
            )
            self.pendingReconciliationIdentifiers.removeAll()
            self.deliver(reconciliationChanges)
        }
    }

    func removeObserver(_ observer: AnyObject) {
        processingQueue.async {
            let observerIdentifier = ObjectIdentifier(observer)
            let wasRegistered = self.observers.contains {
                $0.observer === observer
            }
            self.observers = self.observers.filter {
                $0.observer != nil && $0.observer !== observer
            }

            if wasRegistered, self.observers.isEmpty {
                let deliveryTokens = self.inFlightDeliveries.compactMap {
                    token, delivery in
                    delivery.observerIdentifier == observerIdentifier
                        ? token
                        : nil
                }
                for token in deliveryTokens {
                    guard let delivery = self.inFlightDeliveries.removeValue(
                        forKey: token
                    ) else {
                        continue
                    }

                    self.pendingReconciliationIdentifiers.formUnion(
                        delivery.identifiers
                    )
                }
            }
        }
    }

    private func didReceive(notification: Notification) {
        let updatedObjects = metaAccounts(
            in: notification,
            userInfoKey: NSUpdatedObjectsKey
        ).map(mappedObject)
        let deletedObjectIds = metaAccounts(
            in: notification,
            userInfoKey: NSDeletedObjectsKey
        ).map(\.objectID)
        let insertedObjects = metaAccounts(
            in: notification,
            userInfoKey: NSInsertedObjectsKey
        ).map(mappedObject)

        guard
            !updatedObjects.isEmpty ||
            !deletedObjectIds.isEmpty ||
            !insertedObjects.isEmpty
        else {
            return
        }

        processingQueue.async {
            self.apply(
                updatedObjects: updatedObjects,
                deletedObjectIds: deletedObjectIds,
                insertedObjects: insertedObjects
            )
        }
    }

    private func mappedObject(for entity: CDMetaAccount) -> MappedObject {
        let model: Model?
        if predicate(entity) {
            model = try? mapper.transform(entity: entity)
        } else {
            model = nil
        }

        return MappedObject(
            objectId: entity.objectID,
            model: model
        )
    }

    private func metaAccounts(
        in notification: Notification,
        userInfoKey: String
    ) -> [CDMetaAccount] {
        guard let objects = notification.userInfo?[userInfoKey] as? NSSet else {
            return []
        }

        return objects.allObjects.compactMap { $0 as? CDMetaAccount }
    }

    private func apply(
        updatedObjects: [MappedObject],
        deletedObjectIds: [NSManagedObjectID],
        insertedObjects: [MappedObject]
    ) {
        var mutations: [NSManagedObjectID: ObjectMutation] = [:]
        for object in updatedObjects {
            mutations[object.objectId] = .replace(object.model)
        }
        for object in insertedObjects {
            mutations[object.objectId] = .replace(object.model)
        }
        for objectId in deletedObjectIds {
            mutations[objectId] = .delete
        }

        var affectedIdentifiers = Set<String>()
        for (objectId, mutation) in mutations {
            if let previousModel = trackedModels[objectId] {
                affectedIdentifiers.insert(previousModel.identifier)
            }

            if case let .replace(model) = mutation, let model {
                affectedIdentifiers.insert(model.identifier)
            }
        }

        let modelsBefore = aggregateModels(for: affectedIdentifiers)

        for (objectId, mutation) in mutations {
            switch mutation {
            case let .replace(model):
                trackedModels[objectId] = model
            case .delete:
                trackedModels.removeValue(forKey: objectId)
            }
        }

        let modelsAfter = aggregateModels(for: affectedIdentifiers)
        let changes = affectedIdentifiers.sorted().compactMap { identifier in
            aggregateChange(
                identifier: identifier,
                before: modelsBefore[identifier],
                after: modelsAfter[identifier]
            )
        }
        deliver(changes)
    }

    private func aggregateModels(
        for identifiers: Set<String>
    ) -> [String: Model] {
        guard !identifiers.isEmpty else {
            return [:]
        }

        var models: [String: Model] = [:]
        for (_, model) in trackedModels.sorted(by: objectIdOrder) {
            guard
                identifiers.contains(model.identifier),
                models[model.identifier] == nil
            else {
                continue
            }

            models[model.identifier] = model
        }

        return models
    }

    private func aggregateChange(
        identifier: String,
        before: Model?,
        after: Model?
    ) -> DataProviderChange<Model>? {
        switch (before, after) {
        case (nil, nil):
            return nil
        case (nil, let model?):
            return .insert(newItem: model)
        case (.some, nil):
            return .delete(deletedIdentifier: identifier)
        case let (.some, model?):
            return .update(newItem: model)
        }
    }

    private func reconciliationChanges(
        for identifiers: Set<String>
    ) -> [DataProviderChange<Model>] {
        let currentModels = aggregateModels(for: identifiers)

        return identifiers.sorted().flatMap { identifier in
            var changes: [DataProviderChange<Model>] = [
                .delete(deletedIdentifier: identifier)
            ]
            if let model = currentModels[identifier] {
                changes.append(.insert(newItem: model))
            }

            return changes
        }
    }

    private func deliver(_ changes: [DataProviderChange<Model>]) {
        guard !changes.isEmpty else {
            return
        }

        observers = observers.filter { $0.observer != nil }
        guard !observers.isEmpty else {
            pendingReconciliationIdentifiers.formUnion(
                changes.map(changeIdentifier)
            )
            return
        }

        for observer in observers {
            if processingQueue == observer.queue {
                observer.updateBlock(changes)
            } else {
                guard let observerObject = observer.observer else {
                    continue
                }

                let observerIdentifier = ObjectIdentifier(observerObject)
                let identifiers = Set(changes.map(changeIdentifier))
                let deliveryToken = beginDelivery(
                    identifiers: identifiers,
                    to: observerIdentifier
                )
                observer.queue.async { [weak self] in
                    observer.updateBlock(changes)
                    self?.finishDelivery(deliveryToken)
                }
            }
        }
    }

    private func beginDelivery(
        identifiers: Set<String>,
        to observerIdentifier: ObjectIdentifier
    ) -> UUID {
        let token = UUID()
        inFlightDeliveries[token] = InFlightDelivery(
            observerIdentifier: observerIdentifier,
            identifiers: identifiers
        )
        return token
    }

    private func finishDelivery(_ token: UUID) {
        processingQueue.async {
            self.inFlightDeliveries.removeValue(forKey: token)
        }
    }

    private func changeIdentifier(
        _ change: DataProviderChange<Model>
    ) -> String {
        switch change {
        case let .insert(model), let .update(model):
            return model.identifier
        case let .delete(identifier):
            return identifier
        }
    }

    private func objectIdOrder(
        _ lhs: (key: NSManagedObjectID, value: Model),
        _ rhs: (key: NSManagedObjectID, value: Model)
    ) -> Bool {
        lhs.key.uriRepresentation().absoluteString <
            rhs.key.uriRepresentation().absoluteString
    }
}
