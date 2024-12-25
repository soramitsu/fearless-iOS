import UIKit
import SoraFoundation

protocol EcosystemOptionsViewOutput: AnyObject {
    func didLoad(view: EcosystemOptionsViewInput)
    func didTapOnBackup()
    func didTapOnAccounts()
}

final class EcosystemOptionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = EcosystemOptionsViewLayout

    // MARK: Private properties

    private let output: EcosystemOptionsViewOutput

    // MARK: - Constructor

    init(
        output: EcosystemOptionsViewOutput,
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
        view = EcosystemOptionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
    }

    // MARK: - Private methods

    private func bindActions() {
        rootView.backupWalletButton.addAction { [weak self] in
            self?.output.didTapOnBackup()
        }
        rootView.accountsDetailsButton.addAction { [weak self] in
            self?.output.didTapOnAccounts()
        }
    }
}

// MARK: - EcosystemOptionsViewInput

extension EcosystemOptionsViewController: EcosystemOptionsViewInput {}

// MARK: - Localizable

extension EcosystemOptionsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
