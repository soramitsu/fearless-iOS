import UIKit
import SoraFoundation

protocol ConfirmTransferViewOutput: AnyObject {
    func didLoad(view: ConfirmTransferViewInput)
    func didTapConfirmButton()
    func didTapBackButton()
    func didTapScamWarningButton()
}

final class ConfirmTransferViewController: UIViewController, ViewHolder, HiddableBarWhenPushed, LoadableViewProtocol {
    typealias RootViewType = WalletSendConfirmViewLayout
    var loadableContentView: UIView {
        rootView.contentView
    }

    // MARK: Private properties

    private let output: ConfirmTransferViewOutput

    // MARK: - Constructor

    init(
        output: ConfirmTransferViewOutput,
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
        view = WalletSendConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.receiverWarningButton.addTarget(self, action: #selector(handleScamWarningTapped), for: .touchUpInside)
        rootView.confirmButton.addTarget(self, action: #selector(continueButtonClicked), for: .touchUpInside)
    }

    @objc private func continueButtonClicked() {
        didStartLoading()
        output.didTapConfirmButton()
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func handleScamWarningTapped() {
        output.didTapScamWarningButton()
    }
}

// MARK: - ConfirmTransferViewInput

extension ConfirmTransferViewController: ConfirmTransferViewInput {
    func didReceiveContinueButton(isReady: Bool) {
        rootView.confirmButton.set(enabled: isReady)
    }

    func didReceive(viewModel: WalletSendConfirmViewModel) {
        rootView.bind(confirmViewModel: viewModel)
    }
}

// MARK: - Localizable

extension ConfirmTransferViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
