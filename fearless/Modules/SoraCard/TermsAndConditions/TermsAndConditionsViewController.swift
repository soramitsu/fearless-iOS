import UIKit
import SoraFoundation

final class TermsAndConditionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = TermsAndConditionsViewLayout

    // MARK: Private properties

    private let output: TermsAndConditionsViewOutput

    // MARK: - Constructor

    init(
        output: TermsAndConditionsViewOutput,
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
        view = TermsAndConditionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - TermsAndConditionsViewInput

extension TermsAndConditionsViewController: TermsAndConditionsViewInput {}

// MARK: - Localizable

extension TermsAndConditionsViewController: Localizable {
    func applyLocalization() {}
}
