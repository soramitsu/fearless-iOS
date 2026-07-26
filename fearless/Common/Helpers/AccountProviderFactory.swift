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
/// successfully mapped rows by object ID makes deletes unambiguous and also turns a valid-to-corrupt
/// update into removal of that one previously valid object.
private final class TolerantMetaAccountContextObservable<Model: Identifiable>:
    DataProviderRepositoryObservable {
    private struct MappedObject {
        let objectId: NSManagedObjectID
        let model: Model?
    }

    private let service: CoreDataServiceProtocol
    private let mapper: AnyCoreDataMapper<Model, CDMetaAccount>
    private let predicate: (CDMetaAccount) -> Bool
    private let processingQueue: DispatchQueue

    private var observers: [RepositoryObserver<Model>] = []
    private var trackedModels: [NSManagedObjectID: Model] = [:]
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
        }
    }

    func removeObserver(_ observer: AnyObject) {
        processingQueue.async {
            self.observers = self.observers.filter {
                $0.observer != nil && $0.observer !== observer
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
            var changes: [DataProviderChange<Model>] = []

            for object in updatedObjects {
                self.applyMappedObject(
                    object,
                    preferredChange: .update,
                    to: &changes
                )
            }
            for objectId in deletedObjectIds {
                if let previousModel = self.trackedModels.removeValue(forKey: objectId) {
                    changes.append(
                        .delete(deletedIdentifier: previousModel.identifier)
                    )
                }
            }
            for object in insertedObjects {
                self.applyMappedObject(
                    object,
                    preferredChange: .insert,
                    to: &changes
                )
            }

            self.deliver(changes)
        }
    }

    private enum PreferredChange {
        case insert
        case update
    }

    private func applyMappedObject(
        _ object: MappedObject,
        preferredChange: PreferredChange,
        to changes: inout [DataProviderChange<Model>]
    ) {
        guard let model = object.model else {
            if let previousModel = trackedModels.removeValue(forKey: object.objectId) {
                changes.append(
                    .delete(deletedIdentifier: previousModel.identifier)
                )
            }
            return
        }

        if let previousModel = trackedModels[object.objectId] {
            if previousModel.identifier == model.identifier {
                changes.append(.update(newItem: model))
            } else {
                changes.append(
                    .delete(deletedIdentifier: previousModel.identifier)
                )
                changes.append(.insert(newItem: model))
            }
        } else {
            switch preferredChange {
            case .insert, .update:
                // A previously corrupt/nonmatching object becoming valid is new to the stream,
                // even though Core Data reports it as an update.
                changes.append(.insert(newItem: model))
            }
        }

        trackedModels[object.objectId] = model
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

    private func deliver(_ changes: [DataProviderChange<Model>]) {
        guard !changes.isEmpty else {
            return
        }

        observers = observers.filter { $0.observer != nil }
        for observer in observers {
            if processingQueue == observer.queue {
                observer.updateBlock(changes)
            } else {
                observer.queue.async {
                    observer.updateBlock(changes)
                }
            }
        }
    }
}
