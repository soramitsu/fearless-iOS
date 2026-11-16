import Foundation
import RobinHood
import XCTest
@testable import fearless

final class CovGRepositoryTests: XCTestCase {
    func testSaveFetchUpdateDeleteAndCount() throws {
        let repository = InMemoryDataProviderRepository<CovGRepositoryItem>()
        let first = CovGRepositoryItem(identifier: "first", value: 1)
        let second = CovGRepositoryItem(identifier: "second", value: 2)
        try CovGOperationFixtures.run(repository.saveOperation({ [first, second] }, { [] }))
        XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchCountOperation()), 2)
        XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchOperation(by: { "first" }, options: RepositoryFetchOptions())), first)
        let selection = try CovGOperationFixtures.run(repository.fetchOperation(by: { ["second", "absent"] }, options: RepositoryFetchOptions()))
        XCTAssertEqual(selection, [second])
        let updated = CovGRepositoryItem(identifier: "first", value: 3)
        try CovGOperationFixtures.run(repository.saveBatchOperation({ [updated] }, { ["second", "unknown"] }))
        XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchAllOperation(with: RepositoryFetchOptions())), [updated])
        XCTAssertNil(try CovGOperationFixtures.run(repository.fetchOperation(by: { "second" }, options: RepositoryFetchOptions())))
        try CovGOperationFixtures.run(repository.deleteAllOperation())
        XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchCountOperation()), 0)
        XCTAssertTrue(try CovGOperationFixtures.run(repository.fetchAllOperation(with: RepositoryFetchOptions())).isEmpty)
    }

    func testReplacementReplacesAllItemsAndLastDuplicateWins() throws {
        let repository = InMemoryDataProviderRepository<CovGRepositoryItem>()
        try CovGOperationFixtures.run(repository.saveOperation({ [.init(identifier: "old", value: 1)] }, { [] }))
        try CovGOperationFixtures.run(repository.replaceOperation {
            [.init(identifier: "new", value: 2), .init(identifier: "new", value: 3)]
        })
        XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchAllOperation(with: RepositoryFetchOptions())), [.init(identifier: "new", value: 3)])
    }

    func testThrowingClosuresPropagateErrorsWithoutPartiallySaving() throws {
        let repository = InMemoryDataProviderRepository<CovGRepositoryItem>()
        let error = NSError(domain: "CovG.repository", code: 19)
        try CovGOperationFixtures.run(repository.saveOperation({ [.init(identifier: "old", value: 1)] }, { [] }))
        XCTAssertThrowsError(try CovGOperationFixtures.run(repository.saveOperation({ [.init(identifier: "new", value: 2)] }, { throw error })))
        XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchAllOperation(with: RepositoryFetchOptions())), [.init(identifier: "old", value: 1)])
        XCTAssertThrowsError(try CovGOperationFixtures.run(repository.fetchOperation(by: { () -> String in throw error }, options: RepositoryFetchOptions())))
        XCTAssertThrowsError(try CovGOperationFixtures.run(repository.fetchOperation(by: { () -> [String] in throw error }, options: RepositoryFetchOptions())))
        XCTAssertThrowsError(try CovGOperationFixtures.run(repository.replaceOperation { throw error }))
        XCTAssertEqual(try CovGOperationFixtures.run(repository.fetchCountOperation()), 1)
    }

    func testOperationsOutlivingRepositoryReturnEmptyValues() throws {
        var repository: InMemoryDataProviderRepository<CovGRepositoryItem>? = InMemoryDataProviderRepository()
        let all = try XCTUnwrap(repository?.fetchAllOperation(with: RepositoryFetchOptions()))
        let count = try XCTUnwrap(repository?.fetchCountOperation())
        repository = nil
        XCTAssertTrue(try CovGOperationFixtures.run(all).isEmpty)
        XCTAssertEqual(try CovGOperationFixtures.run(count), 0)
    }
}

private struct CovGRepositoryItem: RobinHood.Identifiable, Equatable {
    let identifier: String
    let value: Int
}

final class CovGTransactionHistoryContextTests: XCTestCase {
    func testSourceContextDefaultsInvalidValuesAndRoundTripsReplacements() {
        let source = TransactionHistorySourceContext(
            context: ["history.page.test": "invalid", "history.row.test": "5", "history.complete.test": "invalid"],
            defaultRow: 9, keySuffix: ".test"
        )
        XCTAssertEqual(source.page, 0)
        XCTAssertEqual(source.row, 5)
        XCTAssertFalse(source.isComplete)
        let updated = source.byReplacingPage(3).byReplacingRow(7).byReplacingCompletion(true)
        XCTAssertEqual(updated.toContext(), ["history.page.test": "3", "history.row.test": "7", "history.complete.test": "true"])
        let restored = TransactionHistorySourceContext(context: updated.toContext(), defaultRow: 99, keySuffix: ".test")
        XCTAssertEqual(restored.page, 3)
        XCTAssertEqual(restored.row, 7)
        XCTAssertTrue(restored.isComplete)
        XCTAssertFalse(source.isComplete)
    }

    func testAllSourceReplacementsPreserveOtherSourcesAndRoundTrip() {
        var history = TransactionHistoryContext(context: [:], defaultRow: 20)
        XCTAssertFalse(history.isComplete)
        for (index, label) in WalletRemoteHistorySourceLabel.allCases.enumerated() {
            let source = history.sourceContext(for: label).byReplacingPage(index + 1).byReplacingCompletion(true)
            history = history.byReplacingSource(context: source, for: label)
            XCTAssertEqual(history.sourceContext(for: label).page, index + 1)
            XCTAssertEqual(history.sourceContext(for: label).row, 20)
        }
        XCTAssertTrue(history.isComplete)
        let restored = TransactionHistoryContext(context: history.toContext(), defaultRow: 99)
        XCTAssertTrue(restored.isComplete)
        XCTAssertEqual(restored.toContext(), history.toContext())
        XCTAssertEqual(restored.defaultRow, 99)
    }

    func testApplyingFiltersCompletesOnlyAbsentSources() {
        let history = TransactionHistoryContext(context: [:], defaultRow: 2)
        let all: [WalletTransactionHistoryFilter] = [
            .init(type: .transfer, selected: true), .init(type: .reward, selected: true), .init(type: .other, selected: true)
        ]
        XCTAssertEqual(history.byApplying(filters: all).toContext(), history.toContext())
        XCTAssertTrue(history.byApplying(filters: []).isComplete)
        let transfers = history.byApplying(filters: [.init(type: .transfer, selected: true)])
        XCTAssertFalse(transfers.transfers.isComplete)
        XCTAssertTrue(transfers.rewards.isComplete)
        XCTAssertTrue(transfers.extrinsics.isComplete)
        let rewards = history.byApplying(filters: [.init(type: .reward, selected: true)])
        XCTAssertTrue(rewards.transfers.isComplete)
        XCTAssertFalse(rewards.rewards.isComplete)
        let extrinsics = history.byApplying(filters: [.init(type: .other, selected: true)])
        XCTAssertFalse(extrinsics.extrinsics.isComplete)
        XCTAssertTrue(extrinsics.rewards.isComplete)
    }
}
