import UIKit
import SoraFoundation

final class SwapTransactionDetailViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapTransactionDetailViewLayout

    // MARK: Private properties

    private let output: SwapTransactionDetailViewOutput

    // MARK: - Constructor

    init(
        output: SwapTransactionDetailViewOutput,
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
        view = SwapTransactionDetailViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindActions()
    }

    // MARK: - Private methods

    private func bindActions() {
        rootView.backButton.addTarget(self, action: #selector(handleDismissTap), for: .touchUpInside)
        rootView.closeButton.addTarget(self, action: #selector(handleDismissTap), for: .touchUpInside)
    }

    @objc private func handleDismissTap() {
        output.didTapDismiss()
    }
}

// MARK: - SwapTransactionDetailViewInput

extension SwapTransactionDetailViewController: SwapTransactionDetailViewInput {
    func didReceive(viewModel: SwapTransactionViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension SwapTransactionDetailViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
