import UIKit
import SoraFoundation

final class ScanQRAssembly {
    static func configureModule(
        moduleOutput: ScanQRModuleOutput,
        matchers: [QRMatcherProtocol] = ScanQRAssembly.defaultMatchers
    ) -> ScanQRModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let qrScanService = QRCaptureServiceFactory().createService(
            delegate: nil,
            delegateQueue: nil
        )

        let interactor = ScanQRInteractor(
            qrExtractionService: QRExtractionService(processingQueue: .global()),
            qrScanService: qrScanService
        )
        let router = ScanQRRouter()

        let presenter = ScanQRPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            moduleOutput: moduleOutput,
            matchers: matchers,
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
            QRInfoMatcher(decoder: QRCoderFactory().createDecoder()),
            QRUriMatcherImpl(scheme: "wc")
        ]
    }

    static let wcSchemeMatcher = QRUriMatcherImpl(scheme: "wc")
}
