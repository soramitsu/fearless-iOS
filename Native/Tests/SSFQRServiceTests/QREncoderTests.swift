import MocksBasket
import XCTest

@testable import SSFQRService

final class QREncoderTests: XCTestCase {
    var qrService: QRService?

    override func setUpWithError() throws {
        try super.setUpWithError()
        qrService = QRServiceDefault()
    }

    override func tearDownWithError() throws {
        qrService = nil
        try super.tearDownWithError()
    }

    func testEncoderError() async throws {
        // arrange
        let expectation =
            expectation(description: "expect call to throw QREncoderError.brokenData error")
        let error = QREncoderError.brokenData
        let encoder = QREncoderMock()
        encoder.encodeWithThrowableError = error
        let qrService = QRServiceDefault(encoder: encoder)

        // act
        do {
            _ = try await qrService.generate(with: .address(""), qrSize: .zero)
        } catch let caughtError {
            XCTAssertTrue(caughtError is QREncoderError)
            XCTAssertEqual(error, caughtError as! QREncoderError)
            expectation.fulfill()
        }

        // assert
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertFalse(encoder.encodeWithCalled)
        XCTAssertEqual(encoder.encodeWithCallsCount, 0)
    }

    func testEncoderMock() async throws {
        // arrange
        let encoder = QREncoderMock()
        encoder.encodeWithReturnValue = .init()

        // act
        _ = try encoder.encode(with: .address(""))

        // assert
        XCTAssertTrue(encoder.encodeWithCalled)
        XCTAssertEqual(encoder.encodeWithCallsCount, 1)
    }

    func testEncoderMockError() async throws {
        // arrange
        let encoder = QREncoderMock()
        encoder.encodeWithThrowableError = QREncoderError.brokenData

        // act
        XCTAssertThrowsError(_ = try encoder.encode(with: .address("")))

        // assert
        XCTAssertFalse(encoder.encodeWithCalled)
        XCTAssertEqual(encoder.encodeWithCallsCount, 0)
    }
}
