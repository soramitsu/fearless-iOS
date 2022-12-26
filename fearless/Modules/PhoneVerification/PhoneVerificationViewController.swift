import UIKit
import SoraFoundation

final class PhoneVerificationViewController: UIViewController, ViewHolder {
    typealias RootViewType = PhoneVerificationViewLayout

    // MARK: Private properties

    private let output: PhoneVerificationViewOutput

    // MARK: - Constructor

    init(
        output: PhoneVerificationViewOutput,
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
        view = PhoneVerificationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - PhoneVerificationViewInput

extension PhoneVerificationViewController: PhoneVerificationViewInput {}

// MARK: - Localizable

extension PhoneVerificationViewController: Localizable {
    func applyLocalization() {}
}
