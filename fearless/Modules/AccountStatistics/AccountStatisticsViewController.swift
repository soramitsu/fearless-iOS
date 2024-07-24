import UIKit
import SoraFoundation

protocol AccountStatisticsViewOutput: AnyObject {
    func didLoad(view: AccountStatisticsViewInput)
    func didTapCloseButton()
    func didTapCopyAddress()
}

final class AccountStatisticsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountStatisticsViewLayout

    // MARK: Private properties

    private let output: AccountStatisticsViewOutput

    // MARK: - Constructor

    init(
        output: AccountStatisticsViewOutput,
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
        view = AccountStatisticsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.closeButton.addAction { [weak self] in
            self?.output.didTapCloseButton()
        }
        rootView.topBar.backButton.addAction { [weak self] in
            self?.output.didTapCloseButton()
        }
        rootView.addressView.onСopied = { [weak self] in
            self?.output.didTapCopyAddress()
        }
    }
}

// MARK: - AccountStatisticsViewInput

extension AccountStatisticsViewController: AccountStatisticsViewInput {
    func didReceive(viewModel: AccountStatisticsViewModel?) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension AccountStatisticsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
