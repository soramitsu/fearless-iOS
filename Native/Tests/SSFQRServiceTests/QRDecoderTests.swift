import MocksBasket
import XCTest

@testable import SSFQRService

final class QRDecoderTests: XCTestCase {
    func testSoraQRDecoder() async throws {
        // arrange
        let prefix = "substrate"
        let address = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let rawPublicKey = "0xbcc5ecf679ebd776866a04c212a4ec5dc45cefab57d7aa858c389844e212693f"
        let username = "Ivan"
        let assetId = "0x0200000000000000000000000000000000000000000000000000000000000000"
        let amount = "123"
        let qrCodeString = "\(prefix):\(address):\(rawPublicKey):\(username):\(assetId):\(amount)"
        let data = qrCodeString.data(using: .utf8)
        let rawPublicKeyData = try Data(hexStringSSF: rawPublicKey)
        XCTAssertNotNil(data)
        let decoder = SoraQRDecoder()

        // act
        let qrType = try decoder.decode(data: data!)

        // assert
        XCTAssertNotNil(qrType)

        switch qrType {
        case let .sora(info):
            XCTAssertEqual(info.prefix, prefix)
            XCTAssertEqual(info.address, address)
            XCTAssertEqual(info.rawPublicKey, rawPublicKeyData)
            XCTAssertEqual(info.username, username)
            XCTAssertEqual(info.assetId, assetId)
            XCTAssertEqual(info.amount, amount)
        case .cex:
            XCTExpectFailure()
        }
    }

    func testSoraQRDecoderWithPrifix() async throws {
        // arrange
        let prefix = "substrate"
        let address = "0xcnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let rawPublicKey = "0xbcc5ecf679ebd776866a04c212a4ec5dc45cefab57d7aa858c389844e212693f"
        let username = "Ivan"
        let assetId = "0x0200000000000000000000000000000000000000000000000000000000000000"
        let amount = "123"
        let qrCodeString = "\(prefix):\(address):\(rawPublicKey):\(username):\(assetId):\(amount)"
        let data = qrCodeString.data(using: .utf8)
        let rawPublicKeyData = try Data(hexStringSSF: rawPublicKey)
        XCTAssertNotNil(data)
        let decoder = SoraQRDecoder()

        // act
        let qrType = try decoder.decode(data: data!)

        // assert
        XCTAssertNotNil(qrType)

        switch qrType {
        case let .sora(info):
            XCTAssertEqual(info.prefix, prefix)
            XCTAssertEqual(info.address, address)
            XCTAssertEqual(info.rawPublicKey, rawPublicKeyData)
            XCTAssertEqual(info.username, username)
            XCTAssertEqual(info.assetId, assetId)
            XCTAssertEqual(info.amount, amount)
        case .cex:
            XCTExpectFailure()
        }
    }

    func testQRDecoderMock() async throws {
        // arrange
        let decoder = QRDecoderMock()
        decoder.decodeDataReturnValue = .cex(.init(address: ""))

        // act
        _ = try decoder.decode(data: Data())

        // assert
        XCTAssertTrue(decoder.decodeDataCalled)
        XCTAssertEqual(decoder.decodeDataCallsCount, 1)
    }
}
