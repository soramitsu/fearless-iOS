import UIKit
import SoraFoundation

final class VerificationStatusViewController: UIViewController, ViewHolder {
    typealias RootViewType = VerificationStatusViewLayout

    // MARK: Private properties
    private let output: VerificationStatusViewOutput

    // MARK: - Constructor
    init(
        output: VerificationStatusViewOutput,
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
        view = VerificationStatusViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }
    
    // MARK: - Private methods
}

// MARK: - VerificationStatusViewInput
extension VerificationStatusViewController: VerificationStatusViewInput {}

// MARK: - Localizable
extension VerificationStatusViewController: Localizable {
    func applyLocalization() {}
}
