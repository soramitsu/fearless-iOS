import UIKit
import FearlessFoundation
import SSFQRService

final class ScanQRAssembly {
    static func configureModule(
        moduleOutput: ScanQRModuleOutput
    ) -> ScanQRModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let qrScanService = QRCaptureServiceFactory().createService(
            delegate: nil,
            delegateQueue: nil
        )

        let qrService = QRServiceDefault()

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
}
