import Foundation
import SoraKeystore
import XCTest
@testable import fearless

final class CovGKeychainTransactionTests: XCTestCase {
    func testTransactionReadsThroughToStoreAndRefusesDeletes() throws {
        let keystore = InMemoryKeychain()
        let transaction = ImportKeychainTransaction(keystore: keystore)
        let tag = "cov-g-\(UUID().uuidString)"
        try transaction.addKey(Data([1, 2]), with: tag)
        XCTAssertEqual(try transaction.fetchKey(for: tag), Data([1, 2]))
        XCTAssertTrue(try transaction.checkKey(for: tag))
        XCTAssertThrowsError(try transaction.deleteKey(for: tag))
        try transaction.updateKey(Data([3]), with: tag)
        XCTAssertEqual(try keystore.fetchKey(for: tag), Data([3]))
        XCTAssertThrowsError(try transaction.addKey(Data([4]), with: tag))
        transaction.commit()
        XCTAssertEqual(try keystore.fetchKey(for: tag), Data([3]))
        XCTAssertThrowsError(try transaction.addKey(Data([5]), with: "\(tag)-after-commit"))
    }
}
