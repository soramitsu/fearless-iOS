import BigInt
import RobinHood
import XCTest
@testable import fearless

/// The balance cache skips writing a balance that has not changed. Its `return` sat inside the lock's read closure,
/// so it only left the closure and every unchanged balance was written again.
final class BalanceRepositoryCacheWrapperTests: XCTestCase {
    func testUnchangedBalanceIsNotWrittenAgain() throws {
        let repository = RecordingStorageWrapperRepository()
        let wrapper = BalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: AnyDataProviderRepository(repository),
            operationManager: InlineOperationManager()
        )
        let balance = AccountInfo(ethBalance: BigUInt(1_000))

        try wrapper.save(data: balance, identifier: "eth-balance")
        try wrapper.save(data: balance, identifier: "eth-balance")
        XCTAssertEqual(repository.savedIdentifiers, [["eth-balance"]], "the same balance is not written again")

        try wrapper.save(data: AccountInfo(ethBalance: BigUInt(2_000)), identifier: "eth-balance")
        XCTAssertEqual(repository.savedIdentifiers.count, 2, "a changed balance is written")
    }
}

/// Runs each operation and then its completion block on the calling thread, so a save and its cache update are done
/// when `enqueue` returns.
final class InlineOperationManager: OperationManagerProtocol {
    func enqueue(operations: [Operation], in _: OperationMode) {
        for operation in operations {
            let completion = operation.completionBlock
            operation.completionBlock = nil
            operation.start()
            completion?()
        }
    }
}

final class RecordingStorageWrapperRepository: DataProviderRepositoryProtocol {
    typealias Model = AccountInfoStorageWrapper

    private let lock = NSLock()
    private var saves: [[String]] = []

    var savedIdentifiers: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return saves
    }

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {
            let models = try updateModelsBlock()
            self.lock.lock()
            self.saves.append(models.map(\.identifier))
            self.lock.unlock()
        }
    }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}
