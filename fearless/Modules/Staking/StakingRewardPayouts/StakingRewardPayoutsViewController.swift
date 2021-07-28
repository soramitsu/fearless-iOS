import UIKit
import SoraFoundation
import SoraUI

final class StakingRewardPayoutsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardPayoutsViewLayout

    // MARK: Properties -

    let presenter: StakingRewardPayoutsPresenterProtocol
    private let localizationManager: LocalizationManagerProtocol?
    private var viewState: StakingRewardPayoutsViewState?
    private let countdownTimer: CountdownTimerProtocol
    private var eraCompletionTime: TimeInterval?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    // MARK: Init -

    init(
        presenter: StakingRewardPayoutsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?,
        countdownTimer: CountdownTimerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        self.countdownTimer = countdownTimer
        super.init(nibName: nil, bundle: nil)
        self.countdownTimer.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        countdownTimer.stop()
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
        title = R.string.localizable
            .stakingRewardPayoutsTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupButtonLocalization() {
        guard let state = viewState else { return }
        if case let StakingRewardPayoutsViewState.payoutsList(viewModel) = state {
            let buttonTitle = viewModel.value(for: selectedLocale).bottomButtonTitle
            rootView.payoutButton.imageWithTitleView?.title = buttonTitle
        }
    }

    private func setupTable() {
        rootView.tableView.registerClassesForCell(
            [StakingRewardHistoryTableCell.self,
             MultilineTableViewCell.self]
        )

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
        countdownTimer.stop()

        switch state {
        case let .loading(isLoading):
            isLoading ? didStartLoading() : didStopLoading()
        case let .payoutsList(viewModel):
            let localizedViewModel = viewModel.value(for: selectedLocale)
            let buttonTitle = localizedViewModel.bottomButtonTitle
            rootView.payoutButton.imageWithTitleView?.title = buttonTitle
            rootView.payoutButton.isHidden = false
            if let time = localizedViewModel.eraComletionTime {
                countdownTimer.start(with: time, runLoop: .main, mode: .common)
            }

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
    func numberOfSections(in _: UITableView) -> Int {
        guard let state = viewState,
              case StakingRewardPayoutsViewState.payoutsList = state
        else { return 1 }
        return 2
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 1 else { return }
        presenter.handleSelectedHistory(at: indexPath.row)
    }
}

extension StakingRewardPayoutsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let state = viewState else { return 1 }
        if case let StakingRewardPayoutsViewState.payoutsList(viewModel) = state {
            return section == 0 ? 1 : viewModel.value(for: selectedLocale).cellViewModels.count
        }
        return 1
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let state = viewState,
            case let StakingRewardPayoutsViewState.payoutsList(viewModel) = state,
            indexPath.section > 0
        else {
            let titleCell = rootView.tableView.dequeueReusableCellWithType(MultilineTableViewCell.self)!
            let title = R.string.localizable
                .stakingPendingRewardsExplanationMessage(preferredLanguages: selectedLocale.rLanguages)
            titleCell.bind(title: title)
            return titleCell
        }

        let cell = rootView.tableView.dequeueReusableCellWithType(
            StakingRewardHistoryTableCell.self)!
        let model = viewModel.value(for: selectedLocale).cellViewModels[indexPath.row]
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
        guard let state = viewState else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error.value(for: selectedLocale)
            errorView.delegate = self
            return errorView
        case .emptyList:
            let emptyView = EmptyStateView()
            emptyView.image = R.image.iconEmptyHistory()
            emptyView.title = R.string.localizable
                .stakingRewardPayoutsEmptyRewards(preferredLanguages: selectedLocale.rLanguages)
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

extension StakingRewardPayoutsViewController: CountdownTimerDelegate {
    func updateView() {
        guard let indexPathsForVisibleRows = rootView.tableView.indexPathsForVisibleRows else { return }

        let historyCells = indexPathsForVisibleRows
            .compactMap { rootView.tableView.cellForRow(at: $0) as? StakingRewardHistoryTableCell }
        guard historyCells.count == indexPathsForVisibleRows.count else { return }

        for (index, cell) in historyCells.enumerated() {
            guard let timeLeftText = presenter.getTimeLeftString(
                at: indexPathsForVisibleRows[index].row
            ) else { return }
            cell.bind(timeLeftText: timeLeftText.value(for: selectedLocale))
        }
    }

    func didStart(with remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didCountdown(remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didStop(with _: TimeInterval) {
        eraCompletionTime = 0
        updateView()
    }
}
