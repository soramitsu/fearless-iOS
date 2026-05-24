import XCTest
@testable import FearlessSecureStorage

final class InMemoryKeychainTests: XCTestCase {
    func testSaveKey_whenKeyIsNew_thenStoresData() throws {
        let keychain = InMemoryKeychain()
        let data = Data([1, 2, 3])

        try keychain.saveKey(data, with: "secret")

        XCTAssertEqual(try keychain.fetchKey(for: "secret"), data)
    }

    func testSaveKey_whenKeyExists_thenUpdatesData() throws {
        let keychain = InMemoryKeychain()

        try keychain.saveKey(Data([1]), with: "secret")
        try keychain.saveKey(Data([2]), with: "secret")

        XCTAssertEqual(try keychain.fetchKey(for: "secret"), Data([2]))
    }

    func testDeleteKeyIfExists_whenKeyIsMissing_thenDoesNotThrow() throws {
        let keychain = InMemoryKeychain()

        XCTAssertNoThrow(try keychain.deleteKeyIfExists(for: "missing"))
    }
}
