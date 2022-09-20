import UIKit
import SoraFoundation

final class WalletSendConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletSendConfirmViewLayout

    let presenter: WalletSendConfirmPresenterProtocol

    private var state: WalletSendConfirmViewState = .loading

    init(presenter: WalletSendConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletSendConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.receiverWarningButton.addTarget(self, action: #selector(handleScamWarningTapped), for: .touchUpInside)
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale
    }

    private func applyState(_ state: WalletSendConfirmViewState) {
        self.state = state

        switch state {
        case .loading:
            break
        case let .loaded(model):
            rootView.bind(confirmViewModel: model)
        }
    }

    @objc private func continueButtonClicked() {
        presenter.didTapConfirmButton()
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }

    @objc private func handleScamWarningTapped() {
        presenter.didTapScamWarningButton()
    }
}

extension WalletSendConfirmViewController: WalletSendConfirmViewProtocol {
    func didReceive(state: WalletSendConfirmViewState) {
        applyState(state)
    }
}

extension WalletSendConfirmViewController: Localizable {
    func applyLocalization() {}
}
