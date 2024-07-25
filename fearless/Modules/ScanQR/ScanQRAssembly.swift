import UIKit
import SoraFoundation
import SSFQRService

final class ScanQRAssembly {
    static func configureModule(
        moduleOutput: ScanQRModuleOutput,
        matchers: [QRMatcher] = ScanQRAssembly.defaultMatchers
    ) -> ScanQRModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let qrScanService = QRCaptureServiceFactory().createService(
            delegate: nil,
            delegateQueue: nil
        )

        let qrService = QRServiceDefault(
            matchers: matchers
        )

        let interactor = ScanQRInteractor(
            qrService: qrService,
            qrScanService: qrScanService
        )
        let router = ScanQRRouter()

        let presenter = ScanQRPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            moduleOutput: moduleOutput,
            localizationManager: LocalizationManager.shared
        )

        let view = ScanQRViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    static var defaultMatchers: [QRMatcher] {
        [
            QRInfoMatcher(decoder: QRDecoderDefault()),
            QRUriMatcherImpl(scheme: "wc")
        ]
    }

    static let wcSchemeMatcher = QRUriMatcherImpl(scheme: "wc")
}
