import XCTest
@testable import fearless

final class ExtrinsicStatusDecodingTests: XCTestCase {
    func testReadyStringAndObjectStatusesDecode() throws {
        let decoder = JSONDecoder()
        guard case .ready = try decoder.decode(ExtrinsicStatus.self, from: Data("\"ready\"".utf8)) else {
            return XCTFail("Expected ready")
        }
        guard case let .inBlock(hash) = try decoder
            .decode(ExtrinsicStatus.self, from: Data(#"{"inBlock":"0x1234"}"#.utf8)) else {
            return XCTFail("Expected inBlock")
        }
        XCTAssertEqual(hash, "0x1234")
    }

    func testUnknownStringsAndMalformedObjectPayloadsStillFail() {
        for json in ["\"unknown\"", "\"inBlock\"", #"{"inBlock":[]}"#, #"{"broadcast":4}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(ExtrinsicStatus.self, from: Data(json.utf8)))
        }
    }
}
