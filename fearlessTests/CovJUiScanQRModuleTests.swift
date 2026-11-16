import XCTest
import UIKit
import AVFoundation
import SoraFoundation
import SSFQRService
@testable import fearless

final class CovJUiScanViewOutput: ScanQRViewOutput {
    private(set) weak var loadedView: ScanQRViewInput?
    private(set) var loads = 0
    private(set) var dismissPreparations = 0
    private(set) var appearancePreparations = 0
    private(set) var dismissals = 0
    private(set) var appearances = 0
    private(set) var imports = 0
    private(set) var backs = 0

    func didLoad(view: ScanQRViewInput) {
        loads += 1
        loadedView = view
    }

    func prepareDismiss() { dismissPreparations += 1 }
    func prepareAppearance() { appearancePreparations += 1 }
    func handleDismiss() { dismissals += 1 }
    func handleAppearance() { appearances += 1 }
    func activateImport() { imports += 1 }
    func didTapBackButton() { backs += 1 }
}

final class CovJUiQRServiceStub: QRService {
    var result: Result<QRMatcherType, Error>
    private(set) var imageRequests = 0

    init(result: Result<QRMatcherType, Error>) {
        self.result = result
    }

    func extractQrCode(from _: UIImage) throws -> QRMatcherType {
        imageRequests += 1
        return try result.get()
    }

    func generate(with _: QRType, qrSize _: CGSize) async throws -> UIImage { UIImage() }
}

final class CovJUiScanInteractorOutput: ScanQRInteractorOutput, QRCaptureServiceDelegate {
    private(set) var errors: [Error] = []
    private(set) var matches: [QRMatcherType] = []

    func handleQRService(error: Error) { errors.append(error) }
    func didReceive(matcher: QRMatcherType) { matches.append(matcher) }
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup _: AVCaptureSession) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didReceive _: Error) {}
}

// MARK: - View controller (hosted with a stub output: nothing here starts or asks for the camera)

final class CovJUiScanQRViewControllerTests: XCTestCase {
    private func makeController(_ output: CovJUiScanViewOutput) throws -> ScanQRViewController {
        ScanQRViewController(output: output, localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")))
    }

    func testHostedScannerWiresLifecycleAndControls() throws {
        let output = CovJUiScanViewOutput()
        let controller = try makeController(output)
        let navigation = UINavigationController(rootViewController: controller)
        let window = try CovJViewFixture.host(navigation)
        defer { window.isHidden = true }

        XCTAssertEqual(output.loads, 1)
        XCTAssertTrue(output.loadedView === controller)
        XCTAssertTrue(CovJWait.until { output.appearances == 1 })
        XCTAssertEqual(output.appearancePreparations, 1)
        XCTAssertTrue(navigation.topViewController === controller)
        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.contactsScan(preferredLanguages: Locale(identifier: "en").rLanguages)
        )

        let frame = controller.rootView.qrFrameView
        XCTAssertEqual(frame.windowPosition, CGPoint(x: 0.5, y: 0.47))
        XCTAssertEqual(frame.windowSize.width, 225 * controller.designScaleRatio.width, accuracy: 0.001)
        XCTAssertEqual(frame.windowSize.height, frame.windowSize.width, accuracy: 0.001)

        controller.rootView.addButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.imports, 1)
        XCTAssertEqual(output.backs, 1)

        controller.viewWillDisappear(false)
        controller.viewDidDisappear(false)
        XCTAssertEqual(output.dismissPreparations, 1)
        XCTAssertEqual(output.dismissals, 1)
    }

    func testMessageIsShownThenHidden() throws {
        let output = CovJUiScanViewOutput()
        let controller = try makeController(output)
        let window = try CovJViewFixture.host(controller)
        defer {
            NSObject.cancelPreviousPerformRequests(withTarget: controller)
            window.isHidden = true
        }

        controller.present(message: "Point the camera at a code", animated: true)
        XCTAssertNotEqual(controller.rootView.messageLabel.text, "Point the camera at a code", "shown on the main queue")
        XCTAssertTrue(CovJWait.until { controller.rootView.messageLabel.text == "Point the camera at a code" })
        XCTAssertEqual(controller.rootView.messageLabel.alpha, 1, accuracy: 0.001)

        _ = controller.perform(NSSelectorFromString("hideMessage"))
        XCTAssertEqual(controller.rootView.messageLabel.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(controller.rootView.messageLabel.text, "Point the camera at a code")
    }

    func testCaptureSessionBecomesTheFramePreviewLayer() throws {
        let output = CovJUiScanViewOutput()
        let controller = try makeController(output)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        XCTAssertNil(controller.rootView.qrFrameView.frameLayer)

        let session = AVCaptureSession()
        controller.didReceive(session: session)
        let layer = try XCTUnwrap(controller.rootView.qrFrameView.frameLayer as? AVCaptureVideoPreviewLayer)
        XCTAssertTrue(layer.session === session)
        XCTAssertEqual(layer.videoGravity, .resizeAspectFill)
        XCTAssertTrue(layer.superlayer === controller.rootView.qrFrameView.layer)

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertTrue(controller.rootView.qrFrameView.frameLayer === layer)
        XCTAssertFalse(session.isRunning, "the view never starts the session")
    }

    func testLocalizationFollowsTheManagerLocale() throws {
        let controller = try makeController(CovJUiScanViewOutput())
        controller.loadViewIfNeeded()
        controller.rootView.locale = Locale(identifier: "ja")
        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.locale.identifier, "en")
        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.contactsScan(preferredLanguages: Locale(identifier: "en").rLanguages)
        )
    }
}

// MARK: - Interactor, assembly and router

final class CovJUiScanQRModuleTests: XCTestCase {
    private func soraMatch(address: String) -> QRMatcherType {
        .qrInfo(.sora(SoraQRInfo(address: address, rawPublicKey: Data([1, 2, 3]), username: "Fixture", assetId: "xor", amount: nil)))
    }

    func testInteractorWiresCaptureServiceAndForwardsStartStop() {
        let capture = CovJUiCaptureService()
        let interactor = ScanQRInteractor(qrService: CovJUiQRServiceStub(result: .failure(CovJError())), qrScanService: capture)
        let output = CovJUiScanInteractorOutput()
        interactor.setup(with: output)
        XCTAssertTrue(capture.delegate === output)

        interactor.startScanning()
        interactor.stopScanning()
        XCTAssertEqual(capture.starts, 1)
        XCTAssertEqual(capture.stops, 1)
    }

    func testGalleryImageFallsBackToStandardDecoderAndReportsMatch() {
        let stub = CovJUiQRServiceStub(result: .success(soraMatch(address: "gallery-address")))
        let interactor = ScanQRInteractor(qrService: stub, qrScanService: CovJUiCaptureService())
        let output = CovJUiScanInteractorOutput()
        interactor.setup(with: output)

        // An empty image fails the wallet's own decoders, so the injected standard service decides.
        interactor.extractQr(from: UIImage())
        XCTAssertEqual(stub.imageRequests, 1)
        XCTAssertEqual(output.matches.map(\.address), ["gallery-address"])
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testGalleryImageErrorsReachOutput() {
        let stub = CovJUiQRServiceStub(result: .failure(CovJError("no code")))
        let interactor = ScanQRInteractor(qrService: stub, qrScanService: CovJUiCaptureService())
        let output = CovJUiScanInteractorOutput()
        interactor.setup(with: output)

        interactor.extractQr(from: UIImage())
        XCTAssertEqual(output.errors.compactMap { $0 as? CovJError }, [CovJError("no code")])

        // A WalletConnect result from the standard decoder is a socket address and is refused.
        stub.result = .success(.walletConnect("ws://node.invalid"))
        interactor.extractQr(from: UIImage())
        XCTAssertEqual(output.errors.count, 2)
        XCTAssertTrue(output.matches.isEmpty)
    }

    func testUnmatchedCameraCodeReportsErrorAndKeepsScanning() {
        let capture = CovJUiCaptureService()
        let stub = CovJUiQRServiceStub(result: .failure(CovJError("plain text")))
        let interactor = ScanQRInteractor(qrService: stub, qrScanService: capture)
        let output = CovJUiScanInteractorOutput()
        interactor.setup(with: output)

        interactor.lookingMatcher(for: "plain text that is no address")
        XCTAssertEqual(output.errors.compactMap { $0 as? CovJError }, [CovJError("plain text")])
        XCTAssertEqual(capture.stops, 0, "a failed frame keeps the camera running")

        stub.result = .success(soraMatch(address: "camera-address"))
        interactor.lookingMatcher(for: "another plain text frame")
        XCTAssertEqual(output.matches.map(\.address), ["camera-address"])
        XCTAssertEqual(capture.stops, 1)
    }

    /// The modules are never put on screen here, so `viewWillAppear` (which starts the camera) never runs.
    func testAssemblyBuildsScannerModulesWithoutStartingTheCamera() throws {
        let output = CovJUiScanModuleOutput()
        let module = try XCTUnwrap(ScanQRAssembly.configureModule(moduleOutput: output))
        let controller = try XCTUnwrap(module.view as? ScanQRViewController)
        XCTAssertNil(controller.view.window)
        XCTAssertTrue(module.input is ScanQRPresenter)

        let raw = CovJUiScanRawOutput()
        let rawModule = try XCTUnwrap(ScanQRAssembly.configureRawModule(rawCodeOutput: raw))
        XCTAssertTrue(rawModule.view.controller is ScanQRViewController)
        XCTAssertFalse(rawModule.view.controller === module.view.controller)
        XCTAssertFalse(rawModule.input === module.input)
    }

    func testRouterCloseDismissesScannerThenCompletes() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let scanner = UIViewController()
        host.controller.present(scanner, animated: false)
        XCTAssertTrue(CovJWait.until { host.presented === scanner })

        var completed = false
        ScanQRRouter().close(view: CovJUiControllerView(scanner)) { completed = true }
        XCTAssertTrue(CovJWait.until(timeout: 3) { completed })
        XCTAssertTrue(CovJWait.until { host.presented == nil })
    }
}
