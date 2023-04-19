import UIKit
import SoraFoundation

final class ScanQRAssembly {
    static func configureModule(moduleOutput: ScanQRModuleOutput) -> ScanQRModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let qrDecoder = QRCoderFactory().createDecoder()
        let qrScanMatcher = QRScanMatcher(decoder: qrDecoder)

        let qrScanService = QRCaptureServiceFactory().createService(
            with: qrScanMatcher,
            delegate: nil,
            delegateQueue: nil
        )

        let interactor = ScanQRInteractor(
            qrDecoder: qrDecoder,
            qrExtractionService: QRExtractionService(processingQueue: .global()),
            qrScanService: qrScanService
        )
        let router = ScanQRRouter()

        let presenter = ScanQRPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            moduleOutput: moduleOutput,
            qrScanMatcher: qrScanMatcher,
            qrScanService: qrScanService,
            localizationManager: LocalizationManager.shared
        )

        let view = ScanQRViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        view.controller.navigationController?.presentingViewController

        return (view, presenter)
    }
}
