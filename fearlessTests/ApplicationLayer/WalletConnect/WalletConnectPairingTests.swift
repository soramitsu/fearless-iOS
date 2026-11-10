import AVFoundation
import CoreImage
import SoraFoundation
import SSFQRService
import UIKit
import FearlessWalletConnect
import XCTest
@testable import fearless

/// WalletConnect pairing codes use the `wc:` scheme (EIP-1328). A scanned or pasted
/// pairing code must reach the WalletConnect service, while node addresses (`ws:` and
/// `wss:`) must never be treated as pairing codes. New connections open together with
/// signing (`WalletConnectSigningPolicy`).
final class WalletConnectPairingTests: XCTestCase {
    private static let pairingCode = "wc:7f6e504bfad60b485450578e05678ed3e8e8c4751d3c6160be17160d63ec90f9@2" +
        "?relay-protocol=irn&symKey=587d5484ce2a2a6ee3ba1962fdd7e8588e06200c46823bd18fbd67def96ad303"

    // MARK: - QR matching

    func testCameraCode_whenPairingCode_thenIsWalletConnect() throws {
        let result = try WalletQRService().extractQrCode(from: Self.pairingCode)

        XCTAssertEqual(result.uri, Self.pairingCode)
    }

    func testCameraCode_whenNodeAddress_thenIsNotWalletConnect() {
        let service = WalletQRService()

        for code in ["ws://node.example:9944", "wss://node.example/ws", "ws:7f6e504b@2?relay-protocol=irn"] {
            let result = try? service.extractQrCode(from: code)
            XCTAssertNil(result?.uri, code)
        }
    }

    func testCameraCode_whenSchemeIsNotLowercase_thenIsNotWalletConnect() {
        // The SDK only accepts the lowercase prefix; anything else would fail to pair.
        let result = try? WalletQRService().extractQrCode(from: Self.pairingCode.replacingOccurrences(of: "wc:", with: "WC:"))

        XCTAssertNil(result?.uri)
    }

    func testGalleryImage_whenPairingCode_thenIsWalletConnect() throws {
        let image = try Self.qrImage(for: Self.pairingCode)

        let result = try WalletQRService().extractQrCode(from: image)

        XCTAssertEqual(result.uri, Self.pairingCode)
    }

    func testGalleryImage_whenNodeAddress_thenIsRefused() throws {
        let image = try Self.qrImage(for: "ws://node.example:9944")

        // The shared decoder alone reports the node address as WalletConnect.
        XCTAssertEqual(try QRServiceDefault().extractQrCode(from: image).uri, "ws://node.example:9944")
        XCTAssertThrowsError(try WalletQRService().extractQrCode(from: image))
    }

    func testScannerInteractor_whenPairingCode_thenDeliversIt() {
        let output = PairingScanOutputSpy()
        let interactor = ScanQRInteractor(qrService: WalletQRService(), qrScanService: PairingScanServiceStub())
        interactor.setup(with: output)
        interactor.startScanning()

        interactor.lookingMatcher(for: Self.pairingCode)

        XCTAssertEqual(output.matches.compactMap(\.uri), [Self.pairingCode])
        XCTAssertTrue(output.errors.isEmpty)
    }

    // MARK: - Connecting

    func testConnect_whenSigningUnavailable_thenNothingIsPaired() async {
        let pairings = PairingRecorder()
        let service = WalletConnectServiceImpl(signingPolicy: .disabled, pair: pairings.record)

        do {
            try await service.connect(uri: Self.pairingCode)
            XCTFail("A new connection must not open while signing is unavailable")
        } catch let error as ConvenienceContentError {
            let languages = LocalizationManager.shared.selectedLocale.rLanguages
            XCTAssertEqual(
                error.title,
                R.string.localizable.walletConnectConnectionUnavailableTitle(preferredLanguages: languages)
            )
            XCTAssertEqual(
                error.message,
                R.string.localizable.walletConnectConnectionUnavailableMessage(preferredLanguages: languages)
            )
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertTrue(pairings.recorded.isEmpty)
    }

    #if DEBUG
        func testConnect_whenSigningEnabled_thenPairsTheScannedCode() async throws {
            let pairings = PairingRecorder()
            let service = WalletConnectServiceImpl(signingPolicy: .enabledForTests, pair: pairings.record)

            try await service.connect(uri: Self.pairingCode)

            XCTAssertEqual(pairings.recorded.map(\.topic), ["7f6e504bfad60b485450578e05678ed3e8e8c4751d3c6160be17160d63ec90f9"])
            XCTAssertEqual(
                pairings.recorded.map(\.symKey),
                ["587d5484ce2a2a6ee3ba1962fdd7e8588e06200c46823bd18fbd67def96ad303"]
            )
        }

        func testConnect_whenCodeIsMalformed_thenShowsTheInvalidCodeErrorAndDoesNotPair() async {
            let pairings = PairingRecorder()
            let service = WalletConnectServiceImpl(signingPolicy: .enabledForTests, pair: pairings.record)

            do {
                try await service.connect(uri: "wc:missing-relay@2")
                XCTFail("A malformed code must not pair")
            } catch let error as ConvenienceContentError {
                let languages = LocalizationManager.shared.selectedLocale.rLanguages
                XCTAssertEqual(error.title, R.string.localizable.walletConnectInvalidUrlTitle(preferredLanguages: languages))
            } catch {
                XCTFail("Unexpected error \(error)")
            }

            XCTAssertTrue(pairings.recorded.isEmpty)
        }
    #endif

    func testConnectionUnavailable_isTranslatedInEveryShippedLocale() {
        let english = R.string.localizable.walletConnectConnectionUnavailableMessage(preferredLanguages: ["en"])
        let shipped = Bundle.main.localizations.filter { $0 != "en" && $0 != "Base" }
        XCTAssertFalse(shipped.isEmpty)

        for identifier in shipped {
            let languages = Locale(identifier: identifier).rLanguages
            let title = R.string.localizable.walletConnectConnectionUnavailableTitle(preferredLanguages: languages)
            let message = R.string.localizable.walletConnectConnectionUnavailableMessage(preferredLanguages: languages)

            XCTAssertNotEqual(message, english, identifier)
            XCTAssertTrue(title.contains("WalletConnect"), identifier)
        }
    }

    // MARK: - Helpers

    static func qrImage(for code: String) throws -> UIImage {
        let filter = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(Data(code.utf8), forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")
        let output = try XCTUnwrap(filter.outputImage)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let bitmap = try XCTUnwrap(CIContext().createCGImage(scaled, from: scaled.extent))
        return UIImage(cgImage: bitmap)
    }
}

private final class PairingRecorder {
    private let lock = NSLock()
    private var uris: [WalletConnectURI] = []

    var recorded: [WalletConnectURI] {
        lock.lock()
        defer { lock.unlock() }
        return uris
    }

    func record(_ uri: WalletConnectURI) async throws {
        lock.lock()
        uris.append(uri)
        lock.unlock()
    }
}

private final class PairingScanOutputSpy: ScanQRInteractorOutput, QRCaptureServiceDelegate {
    private(set) var matches: [QRMatcherType] = []
    private(set) var errors: [Error] = []

    func didReceive(matcher: QRMatcherType) {
        matches.append(matcher)
    }

    func handleQRService(error: Error) {
        errors.append(error)
    }

    func qrCapture(service _: QRCaptureServiceProtocol, didSetup _: AVCaptureSession) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didReceive _: Error) {}
}

private final class PairingScanServiceStub: QRCaptureServiceProtocol {
    var delegate: QRCaptureServiceDelegate?
    var delegateQueue = DispatchQueue.main

    func start() {}
    func stop() {}
}
