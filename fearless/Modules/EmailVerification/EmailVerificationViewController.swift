import UIKit
import SoraFoundation

final class EmailVerificationViewController: UIViewController, ViewHolder {
    typealias RootViewType = EmailVerificationViewLayout

    // MARK: Private properties
    private let output: EmailVerificationViewOutput

    // MARK: - Constructor
    init(
        output: EmailVerificationViewOutput,
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
        view = EmailVerificationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }
    
    // MARK: - Private methods
}

// MARK: - EmailVerificationViewInput
extension EmailVerificationViewController: EmailVerificationViewInput {}

// MARK: - Localizable
extension EmailVerificationViewController: Localizable {
    func applyLocalization() {}
}
