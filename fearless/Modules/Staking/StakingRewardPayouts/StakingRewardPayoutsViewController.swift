import UIKit
import SoraFoundation
import SoraUI

final class StakingRewardPayoutsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardPayoutsViewLayout

    // MARK: Properties -

    let presenter: StakingRewardPayoutsPresenterProtocol
    private let localizationManager: LocalizationManagerProtocol?
    private var viewState: StakingRewardPayoutsViewState?

    // MARK: Init -

    init(
        presenter: StakingRewardPayoutsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle -

    override func loadView() {
        view = StakingRewardPayoutsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTable()
        setupPayoutButtonAction()
        presenter.setup()
    }

    private func setupTitleLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.stakingRewardPayoutsTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupButtonLocalization() {
        // TODO:
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(StakingRewardHistoryTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func setupPayoutButtonAction() {
        rootView.payoutButton.isHidden = true
        rootView.payoutButton.addTarget(
            self,
            action: #selector(handlePayoutButtonAction),
            for: .touchUpInside
        )
    }

    @objc
    private func handlePayoutButtonAction() {
        presenter.handlePayoutAction()
    }
}

extension StakingRewardPayoutsViewController: StakingRewardPayoutsViewProtocol {
    func reload(with state: StakingRewardPayoutsViewState) {
        viewState = state

        switch state {
        case let .loading(isLoading):
            isLoading ? didStartLoading() : didStopLoading()
        case let .payoutsList(viewModel):
            rootView.payoutButton.imageWithTitleView?.title = viewModel.bottomButtonTitle
            rootView.payoutButton.isHidden = false
            rootView.tableView.reloadData()
        case .emptyList, .error:
            rootView.payoutButton.isHidden = true
            rootView.tableView.reloadData()
        }
        reloadEmptyState(animated: true)
    }
}

extension StakingRewardPayoutsViewController: Localizable {
    private func setupLocalization() {
        setupTitleLocalization()
        setupButtonLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            reloadEmptyState(animated: false)
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingRewardPayoutsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.handleSelectedHistory(at: indexPath.row)
    }
}

extension StakingRewardPayoutsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let state = viewState else { return 0 }
        if case let StakingRewardPayoutsViewState.payoutsList(viewModel) = state {
            return viewModel.cellViewModels.count
        }
        return 0
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let state = viewState,
            case let StakingRewardPayoutsViewState.payoutsList(viewModel) = state
        else {
            return UITableViewCell()
        }
        let cell = rootView.tableView.dequeueReusableCellWithType(
            StakingRewardHistoryTableCell.self)!
        let model = viewModel.cellViewModels[indexPath.row]
        cell.bind(model: model)
        return cell
    }
}

extension StakingRewardPayoutsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension StakingRewardPayoutsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard
            let state = viewState,
            let locale = localizationManager?.selectedLocale
        else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error.value(for: locale)
            errorView.delegate = self
            return errorView
        case .emptyList:
            let emptyView = EmptyStateView()
            emptyView.image = R.image.iconEmptyHistory()
            emptyView.title = "Your rewards\nwill appear here" // TODO:
            emptyView.titleColor = R.color.colorLightGray()!
            emptyView.titleFont = .p2Paragraph
            return emptyView
        case .loading, .payoutsList:
            return nil
        }
    }
}

extension StakingRewardPayoutsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = viewState else { return false }
        switch state {
        case .error, .emptyList:
            return true
        case .loading, .payoutsList:
            return false
        }
    }
}

extension StakingRewardPayoutsViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.reload()
    }
}
