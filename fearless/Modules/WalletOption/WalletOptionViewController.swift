import UIKit
import SoraFoundation

final class WalletOptionViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletOptionViewLayout

    // MARK: Private properties

    private let output: WalletOptionViewOutput

    // MARK: - Constructor

    init(
        output: WalletOptionViewOutput,
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
        view = WalletOptionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        output.didLoad(view: self)
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.walletDetailsButton.addTarget(
            self,
            action: #selector(handleWalletDetailsDidTap),
            for: .touchUpInside
        )
        rootView.exportWalletButton.addTarget(
            self,
            action: #selector(handleWalletExportDidTap),
            for: .touchUpInside
        )
        rootView.deleteWalletButton.addTarget(
            self,
            action: #selector(handleDeleteWalletDidTap),
            for: .touchUpInside
        )
    }

    // MARK: - Actions

    @objc private func handleWalletDetailsDidTap() {
        output.walletDetailsDidTap()
    }

    @objc private func handleWalletExportDidTap() {
        output.exportWalletDidTap()
    }

    @objc private func handleDeleteWalletDidTap() {
        output.deleteWalletDidTap()
    }
}

// MARK: - WalletOptionViewInput

extension WalletOptionViewController: WalletOptionViewInput {
    func setDeleteButtonIsVisible(_ isVisible: Bool) {
        rootView.deleteWalletButton.isHidden = !isVisible
    }
}

// MARK: - Localizable

extension WalletOptionViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
