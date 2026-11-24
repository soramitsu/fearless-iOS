import XCTest
import UIKit
import AVFoundation
import SoraFoundation
import SSFQRService
@testable import fearless

// MARK: - Scanner stubs (shared by the CovJUiScanQR* files)

/// A `ControllerBackedProtocol` around any controller, for routers that only touch `view.controller`.
final class CovJUiControllerView: ControllerBackedProtocol {
    let controller: UIViewController
    var isSetup: Bool { true }

    init(_ controller: UIViewController = UIViewController()) {
        self.controller = controller
    }
}

final class CovJUiScanView: ScanQRViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    private(set) var messages: [String] = []
    private(set) var sessions: [AVCaptureSession] = []
    private(set) var loadingStarts = 0
    private(set) var loadingStops = 0

    func didStartLoading() { loadingStarts += 1 }
    func didStopLoading() { loadingStops += 1 }
    func didReceive(session: AVCaptureSession) { sessions.append(session) }
    func present(message: String, animated _: Bool) { messages.append(message) }
}

/// Thread-safe: the presenter restarts scanning from a global queue after an error sheet closes.
final class CovJUiScanInteractor: ScanQRInteractorInput {
    private let lock = NSLock()
    private var startCount = 0
    private(set) weak var output: AnyObject?
    private(set) var stops = 0
    private(set) var images: [UIImage] = []
    private(set) var codes: [String] = []

    var starts: Int {
        lock.lock()
        defer { lock.unlock() }
        return startCount
    }

    func setup(with output: ScanQRInteractorOutput & QRCaptureServiceDelegate) { self.output = output }
    func extractQr(from image: UIImage) { images.append(image) }
    func lookingMatcher(for code: String) { codes.append(code) }
    func stopScanning() { stops += 1 }

    func startScanning() {
        lock.lock()
        startCount += 1
        lock.unlock()
    }
}

final class CovJUiScanRouter: CovJSheetSpy, ScanQRRouterInput {
    private(set) var closes = 0
    private(set) var dismissals = 0
    private(set) var settingsMessages: [String] = []
    private(set) var settingsTitles: [String?] = []
    private(set) var galleryDelegates: [ImageGalleryDelegate] = []

    func close(view _: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        closes += 1
        completion()
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }

    func askOpenApplicationSettings(with message: String, title: String?, from _: ControllerBackedProtocol?) {
        settingsMessages.append(message)
        settingsTitles.append(title)
    }

    func presentImageGallery(
        from _: ControllerBackedProtocol?,
        delegate: ImageGalleryDelegate,
        pickerDelegate _: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    ) {
        galleryDelegates.append(delegate)
    }
}

final class CovJUiScanModuleOutput: ScanQRModuleOutput {
    private(set) var results: [QRMatcherType] = []
    func didFinishWith(scanType: QRMatcherType) { results.append(scanType) }
}

final class CovJUiScanRawOutput: ScanQRRawCodeOutput {
    var accepts = true
    private(set) var checked: [String] = []
    private(set) var finished: [String] = []

    func shouldAccept(rawCode: String) -> Bool {
        checked.append(rawCode)
        return accepts
    }

    func didFinishWith(rawCode: String) { finished.append(rawCode) }
}

final class CovJUiCaptureService: QRCaptureServiceProtocol {
    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue = DispatchQueue.main
    private(set) var starts = 0
    private(set) var stops = 0

    func start() { starts += 1 }
    func stop() { stops += 1 }
}

final class CovJUiScanFixture {
    let view: CovJUiScanView
    let interactor: CovJUiScanInteractor
    let router: CovJUiScanRouter
    let output: CovJUiScanModuleOutput
    let raw: CovJUiScanRawOutput
    let presenter: ScanQRPresenter

    init(rawCodes: Bool, localization: LocalizationManagerProtocol, load: Bool = true) {
        let view = CovJUiScanView()
        let interactor = CovJUiScanInteractor()
        let router = CovJUiScanRouter()
        let output = CovJUiScanModuleOutput()
        let raw = CovJUiScanRawOutput()
        self.view = view
        self.interactor = interactor
        self.router = router
        self.output = output
        self.raw = raw
        presenter = ScanQRPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            moduleOutput: rawCodes ? nil : output,
            rawCodeOutput: rawCodes ? raw : nil,
            localizationManager: localization
        )
        if load {
            presenter.didLoad(view: view)
        }
    }

    static func image(side: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}

// MARK: - Presenter

final class CovJUiScanQRPresenterTests: XCTestCase {
    private let languages = Locale(identifier: "en").rLanguages

    private func fixture(rawCodes: Bool = false, load: Bool = true) throws -> CovJUiScanFixture {
        CovJUiScanFixture(rawCodes: rawCodes, localization: try XCTUnwrap(LocalizationManager(localization: "en")), load: load)
    }

    func testViewInputsReachInteractorAndRouter() throws {
        let f = try fixture()
        XCTAssertTrue(f.interactor.output === f.presenter)

        f.presenter.prepareAppearance()
        XCTAssertEqual(f.interactor.starts, 1)
        f.presenter.handleDismiss()
        XCTAssertEqual(f.interactor.stops, 1)
        f.presenter.didTapBackButton()
        XCTAssertEqual(f.router.dismissals, 1)
        f.presenter.activateImport()
        XCTAssertEqual(f.router.galleryDelegates.count, 1)
        XCTAssertTrue(f.router.galleryDelegates.first === f.presenter)

        f.presenter.applyLocalization()
        XCTAssertTrue(f.view.messages.isEmpty)
        XCTAssertTrue(f.router.sheets.isEmpty)
    }

    func testRestrictedCameraShowsMessageOnlyOnce() throws {
        let f = try fixture()
        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertEqual(f.view.messages, [L10n.InvoiceScan.Error.cameraRestricted])

        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessDeniedPreviously)
        XCTAssertEqual(f.view.messages.count, 1)
        XCTAssertTrue(f.router.settingsMessages.isEmpty, "camera access is asked about once")
    }

    func testPreviouslyDeniedCameraOffersApplicationSettings() throws {
        let f = try fixture()
        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessDeniedPreviously)
        XCTAssertEqual(f.router.settingsMessages, [L10n.InvoiceScan.Error.cameraRestrictedPreviously])
        XCTAssertEqual(f.router.settingsTitles, [L10n.InvoiceScan.Error.cameraTitle])
        XCTAssertTrue(f.view.messages.isEmpty)
    }

    func testCameraDeniedNowStaysSilentAndConsumesTheOnlyPrompt() throws {
        let f = try fixture()
        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessDeniedNow)
        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertTrue(f.view.messages.isEmpty)
        XCTAssertTrue(f.router.settingsMessages.isEmpty)
    }

    func testGalleryErrorsShowMessageOrSettingsEveryTime() throws {
        let f = try fixture()
        f.presenter.didFail(in: f.router, with: ImageGalleryError.accessRestricted)
        XCTAssertEqual(f.view.messages, [L10n.InvoiceScan.Error.galleryRestricted])

        f.presenter.didFail(in: f.router, with: ImageGalleryError.accessDeniedPreviously)
        XCTAssertEqual(f.router.settingsMessages, [L10n.InvoiceScan.Error.galleryRestrictedPreviously])
        XCTAssertEqual(f.router.settingsTitles, [L10n.InvoiceScan.Error.galleryTitle])

        f.presenter.handleQRService(error: ImageGalleryError.accessDeniedNow)
        f.presenter.handleQRService(error: ImageGalleryError.unknownAuthorizationStatus)
        XCTAssertEqual(f.view.messages.count, 1)
        XCTAssertEqual(f.router.settingsMessages.count, 1)

        f.presenter.didFail(in: f.router, with: ImageGalleryError.accessRestricted)
        XCTAssertEqual(f.view.messages.count, 2, "gallery errors are not limited to one prompt")
        XCTAssertTrue(f.router.sheets.isEmpty)
    }

    func testUnexpectedErrorShowsUndefinedSheetAndRestartsScanningWhenItCloses() throws {
        let f = try fixture()
        f.presenter.handleQRService(error: CovJError("undecodable"))
        XCTAssertTrue(f.router.sheets.isEmpty, "the sheet waits for the main queue")
        XCTAssertTrue(CovJWait.until { f.router.sheets.count == 1 })
        XCTAssertEqual(f.view.loadingStarts, 1)

        let sheet = try XCTUnwrap(f.router.sheets.first)
        XCTAssertEqual(sheet.title, R.string.localizable.commonUndefinedErrorMessage(preferredLanguages: languages))
        XCTAssertNil(sheet.message)
        XCTAssertTrue(sheet.actions.isEmpty)
        XCTAssertNil(sheet.closeAction)
        XCTAssertEqual(f.interactor.starts, 0)

        sheet.dismissCompletion?()
        XCTAssertTrue(CovJWait.until { f.interactor.starts == 1 })

        // Closing the sheet counts as the access question: a camera error no longer prompts.
        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertTrue(f.view.messages.isEmpty)
    }

    func testMatcherClosesScannerBeforeReportingResult() throws {
        let f = try fixture()
        f.presenter.didReceive(matcher: .walletConnect("wc:pairing@2"))
        XCTAssertTrue(f.output.results.isEmpty, "delivery waits for the main queue")
        XCTAssertTrue(CovJWait.until { f.output.results.count == 1 })
        XCTAssertEqual(f.router.closes, 1)
        XCTAssertEqual(f.output.results.first?.uri, "wc:pairing@2")
        XCTAssertNil(f.output.results.first?.address)
    }

    func testCameraCodeGoesToMatcherLookupWithoutRawOutput() throws {
        let f = try fixture()
        f.presenter.qrCapture(service: CovJUiCaptureService(), didMatch: "substrate:fixture")
        XCTAssertEqual(f.interactor.codes, ["substrate:fixture"])
        XCTAssertEqual(f.interactor.stops, 0)
        XCTAssertTrue(f.raw.checked.isEmpty)
    }

    func testRawOutputRefusingCodeKeepsScanningAndExplains() throws {
        let f = try fixture(rawCodes: true)
        f.raw.accepts = false
        f.presenter.qrCapture(service: CovJUiCaptureService(), didMatch: "https://example.invalid/not-a-pairing")
        XCTAssertEqual(f.raw.checked, ["https://example.invalid/not-a-pairing"])
        XCTAssertTrue(CovJWait.until { !f.view.messages.isEmpty })
        XCTAssertEqual(f.view.messages, ["This QR code is not a valid IrohaConnect pairing request."])
        XCTAssertEqual(f.interactor.stops, 0)
        XCTAssertTrue(f.interactor.codes.isEmpty)
        XCTAssertEqual(f.router.closes, 0)
        XCTAssertTrue(f.raw.finished.isEmpty)
    }

    func testRawOutputAcceptingCodeStopsScannerClosesAndDelivers() throws {
        let f = try fixture(rawCodes: true)
        f.presenter.qrCapture(service: CovJUiCaptureService(), didMatch: "iroha-connect:pairing")
        XCTAssertEqual(f.interactor.stops, 1)
        XCTAssertTrue(f.raw.finished.isEmpty, "delivery waits for the main queue")
        XCTAssertTrue(CovJWait.until { f.raw.finished == ["iroha-connect:pairing"] })
        XCTAssertEqual(f.router.closes, 1)
        XCTAssertTrue(f.interactor.codes.isEmpty)
        XCTAssertTrue(f.output.results.isEmpty)
    }

    func testCaptureSetupStopsLoadingAndHandsOverSessionOnce() throws {
        let f = try fixture()
        let service = CovJUiCaptureService()
        let session = AVCaptureSession()
        f.presenter.qrCapture(service: service, didSetup: session)
        XCTAssertTrue(CovJWait.until { f.view.loadingStops == 1 })
        XCTAssertEqual(f.view.sessions.count, 1)
        XCTAssertTrue(f.view.sessions.first === session)

        f.presenter.qrCapture(service: service, didSetup: AVCaptureSession())
        XCTAssertTrue(CovJWait.until { f.view.loadingStops == 2 })
        XCTAssertEqual(f.view.sessions.count, 1, "an active scanner keeps its session")

        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertTrue(f.view.messages.isEmpty, "only an initializing scanner reports camera access")
    }

    func testDismissBeforeSetupKeepsInitializingState() throws {
        let f = try fixture()
        f.presenter.prepareDismiss()
        f.presenter.handleAppearance()
        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertEqual(f.view.messages, [L10n.InvoiceScan.Error.cameraRestricted])
    }

    func testDismissAfterSetupDeactivatesUntilAppearance() throws {
        let f = try fixture()
        let service = CovJUiCaptureService()
        f.presenter.qrCapture(service: service, didSetup: AVCaptureSession())
        XCTAssertTrue(CovJWait.until { f.view.sessions.count == 1 })

        f.presenter.prepareDismiss()
        f.presenter.qrCapture(service: service, didSetup: AVCaptureSession())
        XCTAssertTrue(CovJWait.until { f.view.loadingStops == 2 })
        XCTAssertEqual(f.view.sessions.count, 1, "an inactive scanner ignores a new session")

        f.presenter.handleAppearance()
        f.presenter.handleQRService(error: QRCaptureServiceError.deviceAccessDeniedPreviously)
        XCTAssertTrue(f.router.settingsMessages.isEmpty)
        XCTAssertTrue(f.view.messages.isEmpty)
    }

    func testCaptureErrorIsHandledOnTheMainQueue() throws {
        let f = try fixture()
        f.presenter.qrCapture(service: CovJUiCaptureService(), didReceive: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertTrue(f.view.messages.isEmpty)
        XCTAssertTrue(CovJWait.until { f.view.messages == [L10n.InvoiceScan.Error.cameraRestricted] })
    }

    func testGallerySelectionExtractsOnlyTheFirstImage() throws {
        let f = try fixture()
        let first = CovJUiScanFixture.image(side: 3)
        let second = CovJUiScanFixture.image(side: 5)
        f.presenter.didCompleteImageSelection(from: f.router, with: [first, second])
        XCTAssertEqual(f.interactor.images.map(\.size), [CGSize(width: 3, height: 3)])

        f.presenter.didCompleteImageSelection(from: f.router, with: [])
        XCTAssertEqual(f.interactor.images.count, 1)
    }

    func testImagePickerForwardsOriginalImageAndIgnoresCancelOrMissingImage() throws {
        let f = try fixture()
        let picker = UIImagePickerController()
        f.presenter.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: CovJUiScanFixture.image(side: 4)])
        XCTAssertEqual(f.interactor.images.map(\.size), [CGSize(width: 4, height: 4)])

        f.presenter.imagePickerController(picker, didFinishPickingMediaWithInfo: [:])
        f.presenter.imagePickerControllerDidCancel(picker)
        XCTAssertEqual(f.interactor.images.count, 1)
    }
}
