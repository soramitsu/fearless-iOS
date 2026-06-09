import XCTest
@testable import FearlessSecureStorage

final class KeychainManagerTests: XCTestCase {
    func testSaveLoadCheckAndRemoveSecret_whenBackedByInMemoryKeychain_thenCompletesSuccessfully() {
        let manager = KeychainManager(keystore: InMemoryKeychain())
        let completionQueue = DispatchQueue(label: "KeychainManagerTests.completion")
        let identifier = "secret"
        let secret = Data([1, 2, 3])

        let saveExpectation = expectation(description: "save completes")
        manager.saveSecret(secret, for: identifier, completionQueue: completionQueue) { saved in
            XCTAssertTrue(saved)
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: 1)

        XCTAssertTrue(manager.checkSecret(for: identifier))

        let loadExpectation = expectation(description: "load completes")
        manager.loadSecret(for: identifier, completionQueue: completionQueue) { loadedSecret in
            XCTAssertEqual(loadedSecret?.asSecretData(), secret)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 1)

        let removeExpectation = expectation(description: "remove completes")
        manager.removeSecret(for: identifier, completionQueue: completionQueue) { removed in
            XCTAssertTrue(removed)
            removeExpectation.fulfill()
        }
        wait(for: [removeExpectation], timeout: 1)

        XCTAssertFalse(manager.checkSecret(for: identifier))
    }

    func testSaveSecret_whenSecretCannotProduceData_thenReturnsFalse() {
        let manager = KeychainManager(keystore: InMemoryKeychain())
        let completionQueue = DispatchQueue(label: "KeychainManagerTests.completion")
        let saveExpectation = expectation(description: "save completes")

        manager.saveSecret(EmptySecret(), for: "empty", completionQueue: completionQueue) { saved in
            XCTAssertFalse(saved)
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: 1)
        XCTAssertFalse(manager.checkSecret(for: "empty"))
    }
}

private struct EmptySecret: SecretDataRepresentable {
    func asSecretData() -> Data? {
        nil
    }
}
