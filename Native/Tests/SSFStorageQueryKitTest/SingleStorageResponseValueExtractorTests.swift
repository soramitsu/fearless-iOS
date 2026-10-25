import XCTest

@testable import SSFStorageQueryKit

final class SingleStorageResponseValueExtractorTests: XCTestCase {
    func testNilValue() throws {
        let extractor = SingleStorageResponseValueExtractor()
        let responses = [
            StorageResponse<String>(key: Data(), data: nil, value: nil),
        ]

        let value = try extractor.extractValue(storageResponse: responses)
        XCTAssertNil(value)
    }

    func testValue() throws {
        let extractor = SingleStorageResponseValueExtractor()
        let responses = [
            StorageResponse<String>(key: Data(), data: nil, value: "value"),
        ]

        let value = try extractor.extractValue(storageResponse: responses)
        XCTAssertEqual(value, "value")
    }

    func testThrows() throws {
        let extractor = SingleStorageResponseValueExtractor()
        let responses = [
            StorageResponse<String>(key: Data(), data: nil, value: "value"),
            StorageResponse<String>(key: Data(), data: nil, value: "value"),
        ]

        do {
            let _: String? = try extractor.extractValue(storageResponse: responses)
            XCTFail("Error needs to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }
}
