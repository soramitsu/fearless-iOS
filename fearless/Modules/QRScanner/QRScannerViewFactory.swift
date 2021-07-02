import Foundation
import SoraFoundation

struct QRScannerViewFactory {
    static func createBeaconView(for delegate: BeaconQRDelegate) -> QRScannerViewProtocol? {
        let wireframe = QRScannerWireframe()

        let matcher = Tzip10Matcher(delegate: delegate, logger: Logger.shared)
        let qrService = QRCaptureService(matcher: matcher, delegate: nil)
        let presenter = QRScannerPresenter(wireframe: wireframe, qrScanService: qrService, logger: Logger.shared)

        let view = QRScannerViewController(
            title: LocalizableResource { locale in
                R.string.localizable.qrProviderBeacon(preferredLanguages: locale.rLanguages)
            },
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
