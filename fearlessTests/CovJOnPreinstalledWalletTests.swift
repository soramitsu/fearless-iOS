import XCTest
import UIKit
import AVFoundation
import IrohaCrypto
import SoraFoundation
import SSFModels
import SSFQRService
import SoraKeystore
import RobinHood
@testable import fearless

final class CovJOnScanView: UIViewController, ScanQRViewInput {
    var messages: [String] = []
    var sessions: [AVCaptureSession] = []
    var loadingStarts = 0
    var loadingStops = 0
    func didReceive(session: AVCaptureSession) { sessions.append(session) }
    func present(message: String, animated _: Bool) { messages.append(message) }
    func didStartLoading() { loadingStarts += 1 }
    func didStopLoading() { loadingStops += 1 }
}

final class CovJOnPreinstalledInteractor: GetPreinstalledWalletInteractorInput {
    weak var output: GetPreinstalledWalletInteractorOutput?
    var mnemonic: IRMnemonicProtocol?
    var mnemonicInputs: [String] = []
    var requests: [MetaAccountImportRequest] = []
    var images: [UIImage] = []
    var setups = 0
    var starts = 0
    var stops = 0
    func setup() {}
    func setup(with output: GetPreinstalledWalletInteractorOutput) { self.output = output; setups += 1 }
    func importMetaAccount(request: MetaAccountImportRequest) { requests.append(request) }
    func importUniqueChain(request _: UniqueChainImportRequest) {}
    func deriveMetadataFromKeystore(_: String) {}
    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol? {
        mnemonicInputs.append(mnemonicString)
        return mnemonic
    }
    func extractQr(from image: UIImage) { images.append(image) }
    func startScanning() { starts += 1 }
    func stopScanning() { stops += 1 }
}

final class CovJOnPreinstalledRouter: GetPreinstalledWalletRouterInput {
    var errors: [Error] = []
    var errorResults: [Bool] = []
    var settings: [(message: String, title: String?)] = []
    var galleries = 0
    var proceeds = 0
    var dismisses = 0

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return errorResults.isEmpty ? true : errorResults.removeFirst()
    }
    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}
    func present(message _: String?, title _: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]) {}
    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
    func dismiss(view _: ControllerBackedProtocol?) { dismisses += 1 }
    func askOpenApplicationSettings(with message: String, title: String?, from _: ControllerBackedProtocol?) {
        settings.append((message, title))
    }
    func presentImageGallery(
        from _: ControllerBackedProtocol?,
        delegate _: ImageGalleryDelegate,
        pickerDelegate _: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    ) {
        galleries += 1
    }
    func proceed(from _: ControllerBackedProtocol?) { proceeds += 1 }
}

final class CovJOnCaptureService: QRCaptureServiceProtocol {
    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue: DispatchQueue = .main
    func start() {}
    func stop() {}
}

final class CovJOnRootAnimatorSpy: RootControllerAnimationCoordinatorProtocol {
    var controllers: [UIViewController] = []
    func animateTransition(to controller: UIViewController) { controllers.append(controller) }
    func animateTransition(to controller: UIViewController, in _: UIWindow) { controllers.append(controller) }
}

enum CovJOnPhrase {
    static let words = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    static var hex: String { Data(words.utf8).map { String(format: "%02x", $0) }.joined() }
    static func mnemonic() throws -> IRMnemonicProtocol { try IRMnemonicCreator().mnemonic(fromList: words) }
}

final class CovJOnPreinstalledPresenterTests: XCTestCase {
    private func make() -> (GetPreinstalledWalletPresenter, CovJOnPreinstalledInteractor, CovJOnPreinstalledRouter, CovJOnScanView) {
        let interactor = CovJOnPreinstalledInteractor()
        let router = CovJOnPreinstalledRouter()
        let presenter = GetPreinstalledWalletPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
        let view = CovJOnScanView()
        presenter.didLoad(view: view)
        return (presenter, interactor, router, view)
    }

    func testLifecycleInputsReachInteractorAndRouter() {
        let (presenter, interactor, router, _) = make()
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertTrue(interactor.output === presenter)
        presenter.prepareAppearance()
        presenter.handleDismiss()
        presenter.activateImport()
        presenter.didTapBackButton()
        presenter.didCompleteAccountImport()
        presenter.applyLocalization()
        XCTAssertEqual(interactor.starts, 1)
        XCTAssertEqual(interactor.stops, 1)
        XCTAssertEqual(router.galleries, 1)
        XCTAssertEqual(router.dismisses, 1)
        XCTAssertEqual(router.proceeds, 1)
    }

    func testMatchedHexMnemonicImportsPendulumWalletOnceWhileProcessing() throws {
        let (presenter, interactor, _, _) = make()
        interactor.mnemonic = try CovJOnPhrase.mnemonic()
        presenter.handleMatched(code: CovJOnPhrase.hex)
        presenter.handleAddress(CovJOnPhrase.hex)
        presenter.qrCapture(service: CovJOnCaptureService(), didMatch: CovJOnPhrase.hex)

        XCTAssertEqual(interactor.mnemonicInputs, [CovJOnPhrase.words])
        XCTAssertEqual(interactor.requests.count, 1)
        let request = try XCTUnwrap(interactor.requests.first)
        XCTAssertEqual(request.username, "Pendulum Wallet")
        XCTAssertEqual(request.cryptoType, .sr25519)
        XCTAssertEqual(request.defaultChainId, "5d3c298622d5634ed019bf61ea4b71655030015bde9beb0d6a24743714462c86")
        guard case let .mnemonic(data) = request.source else {
            return XCTFail("Expected a mnemonic import source")
        }
        XCTAssertEqual(data.substrateDerivationPath, "")
        XCTAssertEqual(data.ethereumDerivationPath, DerivationPathConstants.defaultEthereum)
        XCTAssertEqual(data.mnemonic.toString(), CovJOnPhrase.words)
    }

    func testInvalidHexFallsBackToUndefinedErrorWhenFirstPresentationIsRefused() {
        let (presenter, interactor, router, _) = make()
        router.errorResults = [false, true]
        presenter.handleAddress("zz-not-hex")
        XCTAssertTrue(CovJWait.until { router.errors.count == 2 })
        XCTAssertEqual(router.errors.first as? AccountCreateError, .invalidMnemonicFormat)
        XCTAssertEqual(router.errors.last as? CommonError, .undefined)
        XCTAssertTrue(interactor.requests.isEmpty)
        XCTAssertTrue(interactor.mnemonicInputs.isEmpty)
    }

    func testUnknownMnemonicIsReportedOnceAndGenericQrErrorReopensProcessing() throws {
        let (presenter, interactor, router, view) = make()
        presenter.handleMatched(code: CovJOnPhrase.hex)
        XCTAssertTrue(CovJWait.until { router.errors.count == 1 })
        CovJWait.drain()
        XCTAssertEqual(router.errors.count, 1, "An accepted presentation must not fall back to the generic error")
        XCTAssertEqual(router.errors.first as? AccountCreateError, .invalidMnemonicFormat)
        XCTAssertEqual(interactor.mnemonicInputs, [CovJOnPhrase.words])

        presenter.handleQRService(error: CovJError())
        XCTAssertEqual(view.messages, [L10n.InvoiceScan.Error.noInfo])

        interactor.mnemonic = try CovJOnPhrase.mnemonic()
        presenter.handleMatched(code: CovJOnPhrase.hex)
        XCTAssertEqual(interactor.requests.count, 1)
    }

    func testCameraRestrictionIsShownOnlyForTheFirstAccessFailure() {
        let (presenter, _, router, view) = make()
        presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        presenter.handleQRService(error: QRCaptureServiceError.deviceAccessDeniedPreviously)
        XCTAssertEqual(view.messages, [L10n.InvoiceScan.Error.cameraRestricted])
        XCTAssertTrue(router.settings.isEmpty)
    }

    func testCameraDeniedPreviouslyAsksForSettingsAndDeniedNowIsSilent() {
        let (presenter, _, router, view) = make()
        presenter.qrCapture(service: CovJOnCaptureService(), didReceive: QRCaptureServiceError.deviceAccessDeniedPreviously)
        XCTAssertTrue(CovJWait.until { router.settings.count == 1 })
        XCTAssertEqual(router.settings.first?.message, L10n.InvoiceScan.Error.cameraRestrictedPreviously)
        XCTAssertEqual(router.settings.first?.title, L10n.InvoiceScan.Error.cameraTitle)

        let (silent, _, silentRouter, silentView) = make()
        silent.handleQRService(error: QRCaptureServiceError.deviceAccessDeniedNow)
        silent.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertTrue(silentView.messages.isEmpty, "Access was already requested once")
        XCTAssertTrue(silentRouter.settings.isEmpty)
        XCTAssertTrue(view.messages.isEmpty)
    }

    func testGalleryErrorsShowMessageOrSettingsPrompt() {
        let (presenter, _, router, view) = make()
        presenter.handleQRService(error: ImageGalleryError.accessRestricted)
        presenter.didFail(in: router, with: ImageGalleryError.accessDeniedPreviously)
        presenter.handleQRService(error: ImageGalleryError.accessDeniedNow)
        presenter.handleQRService(error: ImageGalleryError.unknownAuthorizationStatus)
        XCTAssertEqual(view.messages, [L10n.InvoiceScan.Error.galleryRestricted])
        XCTAssertEqual(router.settings.count, 1)
        XCTAssertEqual(router.settings.first?.message, L10n.InvoiceScan.Error.galleryRestrictedPreviously)
        XCTAssertEqual(router.settings.first?.title, L10n.InvoiceScan.Error.galleryTitle)
    }

    func testCaptureSessionIsDeliveredOnlyWhileInitializing() {
        let (presenter, _, _, view) = make()
        presenter.prepareDismiss()
        let service = CovJOnCaptureService()
        presenter.qrCapture(service: service, didSetup: AVCaptureSession())
        XCTAssertTrue(CovJWait.until { view.sessions.count == 1 })
        presenter.qrCapture(service: service, didSetup: AVCaptureSession())
        CovJWait.drain()
        XCTAssertEqual(view.sessions.count, 1)

        presenter.handleQRService(error: QRCaptureServiceError.deviceAccessRestricted)
        XCTAssertTrue(view.messages.isEmpty, "An active scanner does not ask for access again")
        presenter.prepareDismiss()
        presenter.handleAppearance()
        presenter.handleAppearance()
        presenter.qrCapture(service: service, didSetup: AVCaptureSession())
        CovJWait.drain()
        XCTAssertEqual(view.sessions.count, 1)
    }

    func testPickedAndGalleryImagesAreExtractedButEmptySelectionsAreIgnored() {
        let (presenter, interactor, router, _) = make()
        let image = UIImage()
        let picker = UIImagePickerController()
        presenter.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: image])
        presenter.imagePickerController(picker, didFinishPickingMediaWithInfo: [:])
        presenter.imagePickerControllerDidCancel(picker)
        XCTAssertEqual(interactor.images.count, 1)
        XCTAssertTrue(interactor.images.first === image)

        presenter.didCompleteImageSelection(from: router, with: [image, UIImage()])
        presenter.didCompleteImageSelection(from: router, with: [])
        XCTAssertEqual(interactor.images.count, 2)
        XCTAssertTrue(interactor.images.last === image)
    }
}

final class CovJOnPreinstalledRoutingTests: XCTestCase {
    func testBaseAndExistingUserRoutersStayPutWithoutNavigation() {
        let view = CovJOnScanView()
        GetPreinstalledWalletRouter().proceed(from: view)
        ExistingUserGetPreinstalledWalletRouter().proceed(from: view)
        ExistingUserGetPreinstalledWalletRouter().proceed(from: nil)
        XCTAssertNil(view.navigationController)
        XCTAssertNil(view.presentedViewController)
    }

    func testNewUserRouterHandsAPinScreenToTheRootAnimator() {
        let router = NewUserGetPreinstalledWalletRouter()
        let animator = CovJOnRootAnimatorSpy()
        router.rootAnimator = animator
        router.proceed(from: nil)
        XCTAssertEqual(animator.controllers.count, 1)
        XCTAssertNotNil(animator.controllers.first as? PinSetupViewProtocol)
    }

    func testAssembliesNeedTheKeystoreImportServiceThatUnitTestLaunchesDoNotInstall() {
        let installed: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        let existing = GetPreinstalledWalletAssembly.configureModuleForExistingUser()
        let newUser = GetPreinstalledWalletAssembly.configureModuleForNewUser()
        XCTAssertEqual(existing == nil, installed == nil)
        XCTAssertEqual(newUser == nil, installed == nil)
        if let existing {
            XCTAssertTrue(existing.view.controller is GetPreinstalledWalletViewController)
        }
    }
}

final class CovJOnQRServiceStub: QRService {
    var result: Result<QRMatcherType, Error> = .failure(CovJError("no code"))
    var images: [UIImage] = []
    func extractQrCode(from image: UIImage) throws -> QRMatcherType {
        images.append(image)
        return try result.get()
    }
    func generate(with _: QRType, qrSize _: CGSize) async throws -> UIImage { UIImage() }
}

final class CovJOnScanServiceStub: QRCaptureServiceProtocol {
    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue: DispatchQueue = .main
    var starts = 0
    var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
}

final class CovJOnPreinstalledOutput: GetPreinstalledWalletInteractorOutput {
    var addresses: [String] = []
    var errors: [Error] = []
    func handleQRService(error: Error) { errors.append(error) }
    func handleAddress(_ address: String) { addresses.append(address) }
    func handleMatched(code _: String) {}
    func didCompleteAccountImport() {}
    func didReceiveAccountImport(error _: Error) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup _: AVCaptureSession) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didReceive _: Error) {}
}

final class CovJOnPreinstalledInteractorTests: XCTestCase {
    private func make(qr: CovJOnQRServiceStub, scan: CovJOnScanServiceStub) -> GetPreinstalledWalletInteractor {
        GetPreinstalledWalletInteractor(
            qrService: qr,
            qrScanService: scan,
            accountOperationFactory: MetaAccountOperationFactory(keystore: InMemoryKeychain()),
            accountRepository: AnyDataProviderRepository(CovJMemoryRepository<MetaAccountModel>()),
            operationManager: OperationManager(),
            keystoreImportService: KeystoreImportService(logger: Logger.shared),
            defaultSource: .mnemonic,
            settings: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue()),
            eventCenter: EventCenter.shared
        )
    }

    func testScanningIsForwardedAndOutputBecomesCaptureDelegate() {
        let scan = CovJOnScanServiceStub()
        let interactor = make(qr: CovJOnQRServiceStub(), scan: scan)
        let output = CovJOnPreinstalledOutput()
        interactor.setup(with: output)
        XCTAssertTrue(scan.delegate === output)
        interactor.startScanning()
        interactor.startScanning()
        interactor.stopScanning()
        XCTAssertEqual(scan.starts, 2)
        XCTAssertEqual(scan.stops, 1)
    }

    func testExtractedSoraAddressIsHandedOverAndOtherCodesFail() {
        let qr = CovJOnQRServiceStub()
        let interactor = make(qr: qr, scan: CovJOnScanServiceStub())
        let output = CovJOnPreinstalledOutput()
        interactor.setup(with: output)
        let image = UIImage()

        qr.result = .success(.qrInfo(.sora(SoraQRInfo(address: "5Preinstalled", rawPublicKey: Data(), username: "", assetId: "", amount: nil))))
        interactor.extractQr(from: image)
        XCTAssertEqual(output.addresses, ["5Preinstalled"])
        XCTAssertTrue(output.errors.isEmpty)

        qr.result = .success(.walletConnect("wc:pairing@2"))
        interactor.extractQr(from: image)
        XCTAssertEqual(output.errors.count, 1)
        XCTAssertNotNil(output.errors.first as? ConvenienceError)

        qr.result = .failure(CovJError("unreadable"))
        interactor.extractQr(from: image)
        XCTAssertEqual(output.errors.last as? CovJError, CovJError("unreadable"))
        XCTAssertEqual(qr.images.count, 3)
        XCTAssertEqual(output.addresses.count, 1)
    }
}
