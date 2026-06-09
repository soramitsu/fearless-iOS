import XCTest
import UIKit
import AVFoundation
import IrohaCrypto
import SSFQRService
import FearlessFoundation
@testable import fearless

final class GetPreinstalledWalletTests: XCTestCase {
    func testLifecycleActions_whenCalled_thenDelegateToInteractorAndRouter() {
        let fixture = makeFixture()
        let view = GetPreinstalledWalletViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.prepareAppearance()
        fixture.presenter.activateImport()
        fixture.presenter.didTapBackButton()
        fixture.presenter.handleDismiss()

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didStartScanning)
        XCTAssertTrue(fixture.router.galleryView === view)
        XCTAssertTrue(fixture.router.galleryDelegate === fixture.presenter)
        XCTAssertTrue(fixture.router.pickerDelegate === fixture.presenter)
        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertTrue(fixture.interactor.didStopScanning)
    }

    func testQrCaptureSetup_whenSessionArrives_thenDeliversSessionToView() {
        let fixture = makeFixture()
        let view = GetPreinstalledWalletViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.qrCapture(service: QRCaptureServiceSpy(), didSetup: AVCaptureSession())

        let expectation = expectation(description: "capture session delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertNotNil(view.captureSession)
    }

    func testInvalidMatchedCode_whenHandled_thenPresentsImportError() {
        let fixture = makeFixture()
        let view = GetPreinstalledWalletViewSpy()
        let expectation = expectation(description: "error delivered")
        fixture.router.onPresentError = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleMatched(code: "not-hex-mnemonic")

        wait(for: [expectation], timeout: 1.0)
        guard
            let error = fixture.router.presentedError as? AccountCreateError,
            case .invalidMnemonicFormat = error
        else {
            XCTFail("Expected invalid mnemonic error")
            return
        }
    }

    func testImageGalleryCallbacks_whenImageSelectedOrFails_thenExtractsOrReportsError() {
        let fixture = makeFixture()
        let view = GetPreinstalledWalletViewSpy()
        let image = UIImage()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didCompleteImageSelection(from: fixture.router, with: [image])
        fixture.presenter.didFail(in: fixture.router, with: ImageGalleryError.accessRestricted)

        XCTAssertTrue(fixture.interactor.extractedImage === image)
        XCTAssertEqual(view.presentedMessage, L10n.InvoiceScan.Error.galleryRestricted)
    }

    func testCaptureAndImportErrors_whenReceived_thenUseExpectedPresentation() {
        let fixture = makeFixture()
        let view = GetPreinstalledWalletViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)

        XCTAssertEqual(view.presentedMessage, L10n.InvoiceScan.Error.cameraRestricted)

        let secondFixture = makeFixture()
        let secondView = GetPreinstalledWalletViewSpy()
        secondFixture.presenter.didLoad(view: secondView)
        secondFixture.presenter.handleQRService(error: ImageGalleryError.accessDeniedPreviously)

        XCTAssertEqual(
            secondFixture.router.settingsMessage,
            L10n.InvoiceScan.Error.galleryRestrictedPreviously
        )
        XCTAssertEqual(secondFixture.router.settingsTitle, L10n.InvoiceScan.Error.galleryTitle)
    }

    func testDidCompleteAccountImport_whenInteractorSucceeds_thenProceeds() {
        let fixture = makeFixture()
        let view = GetPreinstalledWalletViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didCompleteAccountImport()

        XCTAssertTrue(fixture.router.proceededView === view)
    }

    func testConfigureModule_whenKeystoreImportServiceMissing_thenReturnsNilAndLogs() {
        let logger = LoggerSpy()
        let dependencies = GetPreinstalledWalletAssembly.Dependencies(
            keystoreImportServiceProvider: { nil },
            localizationManager: LocalizationManager.shared,
            logger: logger
        )

        XCTAssertNil(GetPreinstalledWalletAssembly.configureModuleForExistingUser(dependencies: dependencies))
        XCTAssertNil(GetPreinstalledWalletAssembly.configureModuleForNewUser(dependencies: dependencies))
        XCTAssertEqual(
            logger.errorMessages,
            [
                "Missing required keystore import service",
                "Missing required keystore import service"
            ]
        )
    }

    private func makeFixture() -> GetPreinstalledWalletFixture {
        let interactor = GetPreinstalledWalletInteractorInputSpy()
        let router = GetPreinstalledWalletRouterSpy()
        let presenter = GetPreinstalledWalletPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            logger: LoggerSpy()
        )

        return GetPreinstalledWalletFixture(
            presenter: presenter,
            interactor: interactor,
            router: router
        )
    }
}

private struct GetPreinstalledWalletFixture {
    let presenter: GetPreinstalledWalletPresenter
    let interactor: GetPreinstalledWalletInteractorInputSpy
    let router: GetPreinstalledWalletRouterSpy
}

private final class GetPreinstalledWalletViewSpy: GetPreinstalledWalletViewInput {
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

private final class GetPreinstalledWalletInteractorInputSpy: GetPreinstalledWalletInteractorInput {
    private(set) weak var output: GetPreinstalledWalletInteractorOutput?
    private(set) var didStartScanning = false
    private(set) var didStopScanning = false
    private(set) var extractedImage: UIImage?
    private(set) var importedRequest: MetaAccountImportRequest?

    func setup(with output: GetPreinstalledWalletInteractorOutput) {
        self.output = output
    }

    func setup() {}

    func extractQr(from image: UIImage) {
        extractedImage = image
    }

    func startScanning() {
        didStartScanning = true
    }

    func stopScanning() {
        didStopScanning = true
    }

    func importMetaAccount(request: MetaAccountImportRequest) {
        importedRequest = request
    }

    func importUniqueChain(request _: UniqueChainImportRequest) {}

    func deriveMetadataFromKeystore(_: String) {}

    func createMnemonicFromString(_: String) -> IRMnemonicProtocol? {
        nil
    }
}

private final class GetPreinstalledWalletRouterSpy: GetPreinstalledWalletRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var proceededView: ControllerBackedProtocol?
    private(set) weak var galleryView: ControllerBackedProtocol?
    private(set) weak var galleryDelegate: ImageGalleryDelegate?
    private(set) weak var pickerDelegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?
    private(set) var settingsMessage: String?
    private(set) var settingsTitle: String?
    private(set) var presentedError: Error?
    var onPresentError: (() -> Void)?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func proceed(from view: ControllerBackedProtocol?) {
        proceededView = view
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
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        onPresentError?()
        return true
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class QRCaptureServiceSpy: QRCaptureServiceProtocol {
    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue = DispatchQueue.main

    func start() {}
    func stop() {}
}

private final class LoggerSpy: LoggerProtocol {
    private(set) var errorMessages: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message: String, file _: String, function _: String, line _: Int) {
        errorMessages.append(message)
    }

    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
