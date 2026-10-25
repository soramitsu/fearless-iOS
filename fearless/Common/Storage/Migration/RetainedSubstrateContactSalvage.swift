import Foundation
import RobinHood
import SQLite3
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

/// Best-effort contact recovery never opens the retained file itself. A private
/// family copy includes the WAL, so the last shipped contact edits are retained.
enum RetainedSubstrateContactSalvage {
    static func contacts(from store: URL, fileManager: FileManager = .default) -> [Contact] {
        let root = fileManager.temporaryDirectory.appendingPathComponent("RetainedContacts-" + UUID().uuidString)
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: false)
            defer { try? fileManager.removeItem(at: root) }
            let copy = root.appendingPathComponent(store.lastPathComponent)
            try SQLiteStoreFamilyCopier.copy(
                from: store,
                to: copy,
                includingSharedMemory: false,
                fileManager: fileManager,
                limits: .substrateStorageProduction
            )
            var database: OpaquePointer?
            guard sqlite3_open_v2(copy.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK
            else {
                if let database {
                    sqlite3_close(database)
                }
                return []
            }
            defer { sqlite3_close(database) }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(
                database,
                "SELECT ZADDRESS, ZCHAINID, ZNAME FROM ZCDCONTACT",
                -1,
                &statement,
                nil
            ) ==
                SQLITE_OK else { return [] }
            defer { sqlite3_finalize(statement) }
            var contacts: [Contact] = []
            // Do not let malformed/unbounded cache data hold up healthy wallets.
            var examinedRows = 0
            while examinedRows < 10000, sqlite3_step(statement) == SQLITE_ROW {
                examinedRows += 1
                guard let address = sqlite3_column_text(statement, 0),
                      let chain = sqlite3_column_text(statement, 1),
                      let name = sqlite3_column_text(statement, 2),
                      (0 ..< 3).allSatisfy({ sqlite3_column_bytes(statement, Int32($0)) <= 65536 }) else { continue }
                contacts.append(Contact(
                    name: String(cString: name),
                    address: String(cString: address),
                    chainId: String(cString: chain)
                ))
            }
            return contacts
        } catch { return [] }
    }

    static func missing(_ retained: [Contact], from current: [Contact]) -> [Contact] {
        // The shipped repository keys by address (not address+chain). Avoid
        // overwriting a current contact even when an archive used another chain.
        var knownAddresses = Set(current.map(\.address))
        return retained.filter { knownAddresses.insert($0.address).inserted }
    }

    static func salvageFromRetainedStores() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation {
            let retained = RetainedStoreSetAside(
                storeURL: SubstrateStorageParams.storageURL,
                rootName: RetainedStoreSetAside.substrateRootName,
                fileManager: .default
            )
            guard let archives = try? retained.retainedArchiveURLs(), !archives.isEmpty else { return }
            let contacts = archives
                .flatMap { self.contacts(from: $0.appendingPathComponent(SubstrateStorageParams.databaseName)) }
            guard !contacts.isEmpty else { return }
            let mapper: CodableCoreDataMapper<Contact, SSFAssetManagmentStorage.CDContact> =
                CodableCoreDataMapper(entityIdentifierFieldName: "address")
            let repository: CoreDataRepository<Contact, SSFAssetManagmentStorage.CDContact> = SubstrateDataStorageFacade
                .shared.createRepository(
                    filter: nil,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(mapper)
                )
            let read = repository.fetchAllOperation(with: RepositoryFetchOptions())
            let operations = OperationQueue()
            operations.addOperations([read], waitUntilFinished: true)
            guard let existing = try? read.extractNoCancellableResultData() else { return }
            let additions = missing(contacts, from: existing)
            guard !additions.isEmpty else { return }
            let save = repository.saveOperation({ additions }, { [] })
            operations.addOperations([save], waitUntilFinished: true)
        }
    }
}

final class RetainedContactStartupRecovery: Migrating {
    func migrate() throws {
        RetainedSubstrateContactSalvage.salvageFromRetainedStores()
    }
}
