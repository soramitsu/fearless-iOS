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
        rootView.confirm1Button.addAction { [weak self] in
            self?.rootView.confirm1Button.isChecked.toggle()
            self?.checkContinueButton()
        }
        rootView.confirm2Button.addAction { [weak self] in
            self?.rootView.confirm2Button.isChecked.toggle()
            self?.checkContinueButton()
        }
        rootView.confirm3Button.addAction { [weak self] in
            self?.rootView.confirm3Button.isChecked.toggle()
            self?.checkContinueButton()
        }
    }

    private func checkContinueButton() {
        let isEnabled = rootView.confirm1Button.isChecked
            && rootView.confirm2Button.isChecked
            && rootView.confirm3Button.isChecked
        rootView.continueButton.isEnabled = isEnabled
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
