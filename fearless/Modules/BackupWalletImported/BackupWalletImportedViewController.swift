import UIKit
import SoraFoundation

protocol BackupWalletImportedViewOutput: AnyObject {
    func didLoad(view: BackupWalletImportedViewInput)
    func didBackButtonTapped()
    func didContinueButtonTapped()
    func didImportMoreButtonTapped()
}

final class BackupWalletImportedViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupWalletImportedViewLayout

    // MARK: Private properties

    private let output: BackupWalletImportedViewOutput

    // MARK: - Constructor

    init(
        output: BackupWalletImportedViewOutput,
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
        view = BackupWalletImportedViewLayout()
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
        rootView.importMoreButton.addAction { [weak self] in
            self?.output.didImportMoreButtonTapped()
        }
    }
}

// MARK: - BackupWalletImportedViewInput

extension BackupWalletImportedViewController: BackupWalletImportedViewInput {
    func didReceive(viewModel: BackupWalletImportedViewModel) {
        rootView.bind(walletName: viewModel.walletName)
        rootView.importMoreButton.isHidden = viewModel.importMoreButtomIsHidden
    }
}

// MARK: - Localizable

extension BackupWalletImportedViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
