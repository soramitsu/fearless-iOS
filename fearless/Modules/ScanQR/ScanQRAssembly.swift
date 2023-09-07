import UIKit
import SoraFoundation

final class ScanQRAssembly {
    static func configureModule(
        moduleOutput: ScanQRModuleOutput,
        matchers: [QRMatcherProtocol] = ScanQRAssembly.defaultMatchers
    ) -> ScanQRModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let qrDecoder = QRCoderFactory().createDecoder()
        let qrScanMatcher = QRScanMatcher(decoder: qrDecoder)
        let qrUriMatcher = QRUriMatcherImpl(scheme: "wc")

        let qrScanService = QRCaptureServiceFactory().createService(
            with: matchers,
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
            qrUriMatcher: qrUriMatcher,
            qrScanService: qrScanService,
            localizationManager: LocalizationManager.shared
        )

        let view = ScanQRViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    static var defaultMatchers: [QRMatcherProtocol] {
        [
            QRScanMatcher(decoder: QRCoderFactory().createDecoder()),
            QRUriMatcherImpl(scheme: "wc")
        ]
    }

    static let wcSchemeMatcher = QRUriMatcherImpl(scheme: "wc")
}
