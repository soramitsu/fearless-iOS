import UIKit
import SoraFoundation
import SoraUI

protocol AccountStatisticsViewOutput: AnyObject {
    func didLoad(view: AccountStatisticsViewInput)
    func didTapCloseButton()
    func didTapCopyAddress()
}

final class AccountStatisticsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountStatisticsViewLayout

    // MARK: Private properties

    private let output: AccountStatisticsViewOutput
    private var shouldDisplayEmptyView: Bool = false

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
    func didReceiveError() {
        rootView.setupEmptyState()
        shouldDisplayEmptyView = true
        reloadEmptyState(animated: true)
    }

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

// MARK: - EmptyStateViewOwnerProtocol

extension AccountStatisticsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension AccountStatisticsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarningGray()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.accountStatsErrorMessage(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .smallFilled
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentBackgroundView
    }
}

// MARK: - EmptyStateDelegate

extension AccountStatisticsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        shouldDisplayEmptyView
    }
}
