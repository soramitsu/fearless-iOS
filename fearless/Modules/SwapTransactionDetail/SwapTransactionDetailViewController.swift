import UIKit
import SoraFoundation
import SSFModels

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
        rootView.closeButton.addTarget(self, action: #selector(handleDismissTap), for: .touchUpInside)
        rootView.copyOnTap = { [weak self] in
            self?.output.didTapCopyTxHash()
        }
        rootView.subscanButton.addTarget(self, action: #selector(handleSubscanTapped), for: .touchUpInside)
        rootView.shareButton.addTarget(self, action: #selector(handleShareTapped), for: .touchUpInside)
    }

    @objc private func handleDismissTap() {
        output.didTapDismiss()
    }

    @objc private func handleSubscanTapped() {
        output.didTapSubscan()
    }

    @objc private func handleShareTapped() {
        output.didTapShare()
    }
}

// MARK: - SwapTransactionDetailViewInput

extension SwapTransactionDetailViewController: SwapTransactionDetailViewInput {
    func didReceive(viewModel: SwapTransactionViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(explorer: ChainModel.ExternalApiExplorer?) {
        rootView.updateState(for: explorer)
    }
}

// MARK: - Localizable

extension SwapTransactionDetailViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
