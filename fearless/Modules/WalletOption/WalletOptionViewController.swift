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
        output.didLoad(view: self)
        rootView.delegate = self
    }

    // MARK: - Private methods
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

// MARK: - WalletOptionViewLayoutDelegate

extension WalletOptionViewController: WalletOptionViewLayoutDelegate {
    func walletDetailsDidTap() {
        output.walletDetailsDidTap()
    }

    func exportWalletDidTap() {
        output.exportWalletDidTap()
    }

    func deleteWalletDidTap() {
        output.deleteWalletDidTap()
    }
}
