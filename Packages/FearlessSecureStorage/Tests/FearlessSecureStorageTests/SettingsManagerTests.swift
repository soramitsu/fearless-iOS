import XCTest
@testable import FearlessSecureStorage

final class SettingsManagerTests: XCTestCase {
    func testTypedValues_whenStoredInMemory_thenCanBeReadAndRemoved() {
        let manager = InMemorySettingsManager()
        let data = Data([4, 5, 6])

        manager.set(value: true, for: "bool")
        manager.set(value: 42, for: "integer")
        manager.set(value: 1.25, for: "double")
        manager.set(value: "value", for: "string")
        manager.set(value: data, for: "data")

        XCTAssertEqual(manager.bool(for: "bool"), true)
        XCTAssertEqual(manager.integer(for: "integer"), 42)
        XCTAssertEqual(manager.double(for: "double"), 1.25)
        XCTAssertEqual(manager.string(for: "string"), "value")
        XCTAssertEqual(manager.data(for: "data"), data)

        manager.removeValue(for: "string")
        XCTAssertNil(manager.string(for: "string"))

        manager.removeAll()
        XCTAssertNil(manager.bool(for: "bool"))
        XCTAssertNil(manager.integer(for: "integer"))
        XCTAssertNil(manager.double(for: "double"))
        XCTAssertNil(manager.data(for: "data"))
    }

    func testCodableValue_whenStoredInMemory_thenRoundTripsThroughDataStorage() {
        let manager = InMemorySettingsManager()
        let value = CodablePreference(identifier: "network", enabled: true)

        XCTAssertTrue(manager.set(value: value, for: "preference"))
        XCTAssertEqual(manager.value(of: CodablePreference.self, for: "preference"), value)
    }
}

private struct CodablePreference: Codable, Equatable {
    let identifier: String
    let enabled: Bool
}
