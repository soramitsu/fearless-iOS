import XCTest
import UIKit
import AVFoundation
import FearlessFoundation
import SSFQRService
@testable import fearless

final class WalletScanQRTests: XCTestCase {
    func testDidLoadAndLifecycle_whenCalled_thenDelegatesToInteractorAndRouter() {
        let fixture = makeFixture()
        let view = ScanQRViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.prepareAppearance()
        fixture.presenter.activateImport()
        fixture.presenter.didTapBackButton()
        fixture.presenter.handleDismiss()

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertTrue(fixture.interactor.captureDelegate === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didStartScanning)
        XCTAssertTrue(fixture.router.galleryView === view)
        XCTAssertTrue(fixture.router.galleryDelegate === fixture.presenter)
        XCTAssertTrue(fixture.router.pickerDelegate === fixture.presenter)
        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertTrue(fixture.interactor.didStopScanning)
    }

    func testDidReceiveMatcher_whenInteractorMatches_thenClosesAndNotifiesOutput() {
        let matcher = QRMatcherType.walletConnect("wc:test")
        let fixture = makeFixture()
        let view = ScanQRViewSpy()
        let expectation = expectation(description: "matcher delivered")
        fixture.moduleOutput.onDidFinish = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceive(matcher: matcher)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(fixture.router.closedView === view)
        XCTAssertEqual(fixture.moduleOutput.receivedMatcher?.uri, "wc:test")
    }

    func testQrCaptureCallbacks_whenTriggered_thenUpdateViewAndInteractor() {
        let fixture = makeFixture()
        let view = ScanQRViewSpy()
        let qrService = QRCaptureServiceSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.qrCapture(service: qrService, didSetup: AVCaptureSession())
        fixture.presenter.qrCapture(service: qrService, didMatch: "raw-code")

        let expectation = expectation(description: "capture session delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(view.didStopLoadingCalled)
        XCTAssertNotNil(view.captureSession)
        XCTAssertEqual(fixture.interactor.lookupCode, "raw-code")
    }

    func testAccessErrors_whenReceived_thenShowMessageOrSettingsPrompt() {
        let fixture = makeFixture()
        let view = ScanQRViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)

        XCTAssertEqual(view.presentedMessage, L10n.InvoiceScan.Error.cameraRestricted)

        let secondFixture = makeFixture()
        let secondView = ScanQRViewSpy()
        secondFixture.presenter.didLoad(view: secondView)
        secondFixture.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessDeniedPreviously)

        XCTAssertEqual(secondFixture.router.settingsMessage, L10n.InvoiceScan.Error.cameraRestrictedPreviously)
        XCTAssertEqual(secondFixture.router.settingsTitle, L10n.InvoiceScan.Error.cameraTitle)
    }

    func testImageGalleryCallbacks_whenImageSelectedOrFails_thenExtractsOrReportsError() {
        let fixture = makeFixture()
        let view = ScanQRViewSpy()
        let image = UIImage()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didCompleteImageSelection(from: fixture.router, with: [image])
        fixture.presenter.didFail(in: fixture.router, with: ImageGalleryError.accessRestricted)

        XCTAssertTrue(fixture.interactor.extractedImage === image)
        XCTAssertEqual(view.presentedMessage, L10n.InvoiceScan.Error.galleryRestricted)
    }

    private func makeFixture() -> WalletScanQRFixture {
        let interactor = ScanQRInteractorInputSpy()
        let router = ScanQRRouterSpy()
        let moduleOutput = ScanQRModuleOutputSpy()
        let presenter = ScanQRPresenter(
            interactor: interactor,
            router: router,
            logger: LoggerSpy(),
            moduleOutput: moduleOutput,
            localizationManager: LocalizationManager.shared
        )

        return WalletScanQRFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            moduleOutput: moduleOutput
        )
    }
}

private struct WalletScanQRFixture {
    let presenter: ScanQRPresenter
    let interactor: ScanQRInteractorInputSpy
    let router: ScanQRRouterSpy
    let moduleOutput: ScanQRModuleOutputSpy
}

private final class ScanQRViewSpy: ScanQRViewInput {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true

    private(set) var captureSession: AVCaptureSession?
    private(set) var presentedMessage: String?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceive(session: AVCaptureSession) {
        captureSession = session
    }

    func present(message: String, animated _: Bool) {
        presentedMessage = message
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }
}

private final class ScanQRInteractorInputSpy: ScanQRInteractorInput {
    private(set) weak var output: ScanQRInteractorOutput?
    private(set) weak var captureDelegate: QRCaptureServiceDelegate?
    private(set) var didStartScanning = false
    private(set) var didStopScanning = false
    private(set) var extractedImage: UIImage?
    private(set) var lookupCode: String?

    func setup(with output: ScanQRInteractorOutput & QRCaptureServiceDelegate) {
        self.output = output
        captureDelegate = output
    }

    func extractQr(from image: UIImage) {
        extractedImage = image
    }

    func startScanning() {
        didStartScanning = true
    }

    func stopScanning() {
        didStopScanning = true
    }

    func lookingMatcher(for code: String) {
        lookupCode = code
    }
}

private final class ScanQRRouterSpy: ScanQRRouterInput {
    private(set) weak var closedView: ControllerBackedProtocol?
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var galleryView: ControllerBackedProtocol?
    private(set) weak var galleryDelegate: ImageGalleryDelegate?
    private(set) weak var pickerDelegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?
    private(set) var settingsMessage: String?
    private(set) var settingsTitle: String?
    private(set) var presentedSheet: SheetAlertPresentableViewModel?

    func close(view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        closedView = view
        completion()
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentImageGallery(
        from view: ControllerBackedProtocol?,
        delegate: ImageGalleryDelegate,
        pickerDelegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    ) {
        galleryView = view
        galleryDelegate = delegate
        self.pickerDelegate = pickerDelegate
    }

    func askOpenApplicationSettings(
        with message: String,
        title: String?,
        from _: ControllerBackedProtocol?
    ) {
        settingsMessage = message
        settingsTitle = title
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedSheet = viewModel
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class ScanQRModuleOutputSpy: ScanQRModuleOutput {
    private(set) var receivedMatcher: QRMatcherType?
    var onDidFinish: (() -> Void)?

    func didFinishWith(scanType: QRMatcherType) {
        receivedMatcher = scanType
        onDidFinish?()
    }
}

private final class QRCaptureServiceSpy: QRCaptureServiceProtocol {
    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue = DispatchQueue.main
    private(set) var didStart = false
    private(set) var didStop = false

    func start() {
        didStart = true
    }

    func stop() {
        didStop = true
    }
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
