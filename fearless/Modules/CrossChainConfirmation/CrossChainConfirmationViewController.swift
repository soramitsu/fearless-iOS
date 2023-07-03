import UIKit
import SoraFoundation

protocol CrossChainConfirmationViewOutput: AnyObject {
    func didLoad(view: CrossChainConfirmationViewInput)
    func backButtonDidTapped()
    func confirmButtonTapped()
}

final class CrossChainConfirmationViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = CrossChainConfirmationViewLayout

    // MARK: Private properties

    private let output: CrossChainConfirmationViewOutput

    // MARK: - Constructor

    init(
        output: CrossChainConfirmationViewOutput,
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
        view = CrossChainConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonDidTapped()
        }
        rootView.confirmButton.addAction { [weak self] in
            self?.output.confirmButtonTapped()
        }
    }
}

// MARK: - CrossChainConfirmationViewInput

extension CrossChainConfirmationViewController: CrossChainConfirmationViewInput {
    func didReceive(viewModel: CrossChainConfirmationViewModel) {
        rootView.bind(confirmViewModel: viewModel)
    }

    func didStartLoading() {
        rootView.confirmButton.set(loading: true)
    }

    func didStopLoading() {
        rootView.confirmButton.set(loading: false)
    }
}

// MARK: - Localizable

extension CrossChainConfirmationViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
