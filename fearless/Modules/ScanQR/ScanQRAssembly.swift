import UIKit
import SoraFoundation
import SSFQRService

final class ScanQRAssembly {
    static func configureModule(
        moduleOutput: ScanQRModuleOutput
    ) -> ScanQRModuleCreationResult? {
        configureModule(moduleOutput: moduleOutput, rawCodeOutput: nil)
    }

    static func configureRawModule(
        rawCodeOutput: ScanQRRawCodeOutput
    ) -> ScanQRModuleCreationResult? {
        configureModule(moduleOutput: nil, rawCodeOutput: rawCodeOutput)
    }

    private static func configureModule(
        moduleOutput: ScanQRModuleOutput?,
        rawCodeOutput: ScanQRRawCodeOutput?
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
            rawCodeOutput: rawCodeOutput,
            localizationManager: LocalizationManager.shared
        )

        let view = ScanQRViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
