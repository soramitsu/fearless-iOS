import UIKit
import SoraFoundation

protocol BackupRiskWarningsViewOutput: AnyObject {
    func didLoad(view: BackupRiskWarningsViewInput)
    func didBackButtonTapped()
    func didContinueButtonTapped()
}

final class BackupRiskWarningsViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupRiskWarningsViewLayout

    // MARK: Private properties

    private let output: BackupRiskWarningsViewOutput

    // MARK: - Constructor

    init(
        output: BackupRiskWarningsViewOutput,
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
        view = BackupRiskWarningsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
    }

    // MARK: - Private methods

    private func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }
        rootView.continueButton.addAction { [weak self] in
            self?.output.didContinueButtonTapped()
        }
    }
}

// MARK: - BackupRiskWarningsViewInput

extension BackupRiskWarningsViewController: BackupRiskWarningsViewInput {}

// MARK: - Localizable

extension BackupRiskWarningsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
