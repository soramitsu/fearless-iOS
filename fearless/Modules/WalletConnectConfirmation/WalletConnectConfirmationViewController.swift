import UIKit
import SoraFoundation

protocol WalletConnectConfirmationViewOutput: AnyObject {
    func didLoad(view: WalletConnectConfirmationViewInput)
    func backButtonDidTapped()
    func rawDataDidTapped()
    func confirmDidTapped()
}

final class WalletConnectConfirmationViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectConfirmationViewLayout

    // MARK: Private properties

    private let output: WalletConnectConfirmationViewOutput

    // MARK: - Constructor

    init(
        output: WalletConnectConfirmationViewOutput,
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
        view = WalletConnectConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
    }

    // MARK: - Private methods

    func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonDidTapped()
        }

        rootView.rawDataOnTap = { [weak self] in
            self?.output.rawDataDidTapped()
        }

        rootView.confirmButton.addAction { [weak self] in
            self?.output.confirmDidTapped()
        }
    }
}

// MARK: - WalletConnectConfirmationViewInput

extension WalletConnectConfirmationViewController: WalletConnectConfirmationViewInput {
    func didReceive(viewModel: WalletConnectConfirmationViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension WalletConnectConfirmationViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
