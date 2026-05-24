import XCTest
@testable import FearlessFoundation

final class QueryDecoderTests: XCTestCase {
    func testDecode_whenQueryContainsKeyValuePairs_thenDecodesStringModel() throws {
        let decoder = QueryDecoder()
        let result = try decoder.decode(QueryPayload.self, query: "address=cnVudGltZQ&chain=sora&empty=")

        XCTAssertEqual(result.address, "cnVudGltZQ")
        XCTAssertEqual(result.chain, "sora")
        XCTAssertEqual(result.empty, "")
    }

    func testDecode_whenFragmentHasNoSeparator_thenThrowsEmptyKeyValueSeparator() {
        let decoder = QueryDecoder()

        XCTAssertThrowsError(try decoder.decode(QueryPayload.self, query: "address")) { error in
            guard case QueryDecoderError.emptyKeyValueSeparator(let fragment) = error else {
                XCTFail("Expected emptyKeyValueSeparator, got \(error)")
                return
            }

            XCTAssertEqual(fragment, "address")
        }
    }
}

private struct QueryPayload: Decodable, Equatable {
    let address: String
    let chain: String
    let empty: String
}
