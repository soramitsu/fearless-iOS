import MocksBasket
import XCTest

@testable import SSFQRService

final class QRServiceTests: XCTestCase {
    var qrService: QRService?

    override func setUpWithError() throws {
        try super.setUpWithError()
        qrService = QRServiceDefault()
    }

    override func tearDownWithError() throws {
        qrService = nil
        try super.tearDownWithError()
    }

    func testQRImage() async throws {
        // arrange
        let address = "5GLDeyxgNzsnm4NeSHZd9imbSMaV2RUPGRSkchxsUqSbfBpu"
        let qrSize = CGSize(width: 100.0, height: 120.0)

        // act
        let image = try await qrService?.generate(with: .address(address), qrSize: qrSize)

        // assert
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, qrSize)
    }

    func testGenerateAddress() async throws {
        // arrange
        let address = "5GLDeyxgNzsnm4NeSHZd9imbSMaV2RUPGRSkchxsUqSbfBpu"
        let qrSize = CGSize(width: 500, height: 500)

        // act
        let image = try await qrService?.generate(with: .address(address), qrSize: qrSize)

        // assert
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, qrSize)
        let qrMatcher = try qrService?.extractQrCode(from: image!)
        XCTAssertNotNil(qrMatcher)
        XCTAssertEqual(qrMatcher?.address, address)
    }

    func testGenerateSoraQRInfo() async throws {
        // arrange
        let rawPublicKey = "0xbcc5ecf679ebd776866a04c212a4ec5dc45cefab57d7aa858c389844e212693f"
        let qrSize = CGSize(width: 500, height: 500)
        let qrInfo = try SoraQRInfo(
            address: "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm",
            rawPublicKey: Data(hexStringSSF: rawPublicKey),
            username: "UserName",
            assetId: "0x0200000000000000000000000000000000000000000000000000000000000000",
            amount: "123"
        )

        // act
        let image = try await qrService?.generate(with: .addressInfo(qrInfo), qrSize: qrSize)

        // assert
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, qrSize)
        let qrMatcher = try qrService?.extractQrCode(from: image!)
        XCTAssertNotNil(qrMatcher)
        XCTAssertEqual(qrMatcher?.address, qrInfo.address)

        switch qrMatcher!.qrInfo {
        case let .sora(qrInfoResult):
            XCTAssertEqual(qrInfoResult, qrInfo)
        case .none, .some:
            XCTExpectFailure()
        }
    }

    func testGenerateMock() async throws {
        // arrange
        let qrService = QRServiceMock()
        qrService.generateWithQrSizeReturnValue = .init()

        // act
        let image = try qrService.generate(with: .address(""), qrSize: .init())

        // assert
        XCTAssertNotNil(image)
        XCTAssertEqual(qrService.generateWithQrSizeCallsCount, 1)
        XCTAssertTrue(qrService.generateWithQrSizeCalled)
    }

    func testExtractCex() async throws {
        // arrange
        let qrService = QRServiceMock()
        let qrInfo = CexQRInfo(address: "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm")
        qrService.extractQrCodeFromReturnValue = .qrInfo(.cex(qrInfo))

        // act
        let qrMatcher = try qrService.extractQrCode(from: .init())

        // assert
        XCTAssertEqual(qrService.extractQrCodeFromCallsCount, 1)
        XCTAssertNotNil(qrMatcher)
        XCTAssertEqual(qrMatcher.address, qrInfo.address)

        switch qrMatcher.qrInfo {
        case let .cex(qrInfoResult):
            XCTAssertEqual(qrInfoResult, qrInfo)
        case .none, .some:
            XCTExpectFailure()
        }
    }

    func testExtractError() async throws {
        // arrange
        let qrService = QRServiceMock()
        let error = QRExtractionError.invalidImage
        qrService.extractQrCodeFromThrowableError = error

        // act
        XCTAssertThrowsError(try qrService.extractQrCode(from: .init()))

        // assert
        XCTAssertEqual(qrService.extractQrCodeFromCallsCount, 0)
    }

    func testExtractionErrorInvalidImage() async throws {
        // arrange
        let address = "5GLDeyxgNzsnm4NeSHZd9imbSMaV2RUPGRSkchxsUqSbfBpu"
        let qrSize = CGSize(width: 100.0, height: 120.0)
        let qrService = QRServiceDefault(matchers: [])
        let error = QRExtractionError.invalidImage
        let image = try await qrService.generate(with: .address(address), qrSize: qrSize)

        // act assert
        XCTAssertThrowsError(try qrService.extractQrCode(from: image))
    }

    func testExtractionErrorSeveralCoincidences() async throws {
        // arrange
        let address = "5GLDeyxgNzsnm4NeSHZd9imbSMaV2RUPGRSkchxsUqSbfBpu"
        let qrSize = CGSize(width: 100.0, height: 120.0)
        let matchers = [
            QRInfoMatcher(decoder: QRDecoderDefault()),
            QRInfoMatcher(decoder: QRDecoderDefault()),
        ]
        let qrService = QRServiceDefault(matchers: matchers)
        let error = QRExtractionError.invalidImage
        let image = try await qrService.generate(with: .address(address), qrSize: qrSize)

        // act assert
        XCTAssertThrowsError(try qrService.extractQrCode(from: image))
    }

    func testGenerateError() async throws {
        // arrange
        let qrService = QRServiceMock()
        let error = QRExtractionError.invalidQrCode
        qrService.generateWithQrSizeThrowableError = error

        // act
        XCTAssertThrowsError(try qrService.generate(with: .address(""), qrSize: .zero))

        // assert
        XCTAssertEqual(qrService.extractQrCodeFromCallsCount, 0)
    }

    func testExtractionErrorError() async throws {
        // arrange
        let rawPublicKey = "0xbcc5ecf679ebd776866a04c212a4ec5dc45cefab57d7aa858c389844e212693f"
        let qrInfo = try SoraQRInfo(
            address: "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm",
            rawPublicKey: Data(hexStringSSF: rawPublicKey),
            username: "UserName",
            assetId: "0x0200000000000000000000000000000000000000000000000000000000000000",
            amount: "123"
        )
        let expectation = expectation(description: "expect call to throw QRExtractionError error")
        let error = QRExtractionError.noFeatures
        let decoder = QRDecoderMock()
        decoder.decodeDataThrowableError = error
        let qrService = QRServiceDefault(matchers: [QRInfoMatcher(decoder: decoder)])
        let image = try await qrService.generate(
            with: .addressInfo(qrInfo),
            qrSize: .init(width: 50, height: 50)
        )

        // act
        do {
            _ = try qrService.extractQrCode(from: image)
        } catch let caughtError {
            XCTAssertTrue(caughtError is QRExtractionError)
            XCTAssertEqual(error, caughtError as! QRExtractionError)
            expectation.fulfill()
        }

        // assert
        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertFalse(decoder.decodeDataCalled)
        XCTAssertEqual(decoder.decodeDataCallsCount, 0)
    }

    func testQRCreationOperationError() async throws {
        // arrange
        let error = QRCreationOperationError.bitmapImageCreationFailed
        let expectation =
            expectation(description: "expect call to throw QRCreationOperationError error")
        let qrService = QRServiceDefault()

        // act
        do {
            _ = try await qrService.generate(with: .address(""), qrSize: .zero)
        } catch let caughtError {
            XCTAssertTrue(caughtError is QRCreationOperationError)
            XCTAssertEqual(error, caughtError as! QRCreationOperationError)
            expectation.fulfill()
        }

        // assert
        await fulfillment(of: [expectation], timeout: 3)
    }
}
