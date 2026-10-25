import XCTest

@testable import SSFQRService

final class QRMatcherTests: XCTestCase {
    func testQRUriMatcherMatchesConfiguredScheme() async throws {
        // arrange
        let code = "https://example.com/data?qr=000201010211"
        let matcher = QRUriMatcherImpl(scheme: "https")

        // act
        let qrType = matcher.match(code: code)

        // assert
        XCTAssertNotNil(qrType)
        XCTAssertNil(qrType?.address)
        XCTAssertNil(qrType?.qrInfo)
        XCTAssertEqual(qrType?.uri, code)
    }

    func testQRUriMatcherRejectsOtherScheme() async throws {
        // arrange
        let matcher = QRUriMatcherImpl(scheme: "wc")

        // act
        let qrType = matcher.match(code: "https://example.com/data?qr=000201010211")

        // assert
        XCTAssertNil(qrType)
    }

    func testQRUriMatcherEmpty() async throws {
        // arrange
        let matcher = QRUriMatcherImpl(scheme: "https")

        // act
        let qrType = matcher.match(code: "")

        // assert
        XCTAssertNil(qrType)
    }
}
