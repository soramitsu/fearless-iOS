import UIKit
import SoraFoundation

final class ScanQRViewController: UIViewController, ViewHolder {
    typealias RootViewType = ScanQRViewLayout

    // MARK: Private properties

    private let output: ScanQRViewOutput

    // MARK: - Constructor

    init(
        output: ScanQRViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = ScanQRViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - ScanQRViewInput

extension ScanQRViewController: ScanQRViewInput {}

// MARK: - Localizable

extension ScanQRViewController: Localizable {
    func applyLocalization() {}
}
