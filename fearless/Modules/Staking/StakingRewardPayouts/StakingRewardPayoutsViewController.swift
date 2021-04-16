import UIKit
import SoraFoundation
import SoraUI

final class StakingRewardPayoutsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardPayoutsViewLayout

    // MARK: Properties -

    let presenter: StakingRewardPayoutsPresenterProtocol
    private var cellViewModels: [StakingRewardHistoryCellViewModel] = []

    // MARK: Init -

    init(presenter: StakingRewardPayoutsPresenterProtocol) {
        self.presenter = presenter
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
    func showRetryState() {
        // TODO:
    }

    func reload(with viewModel: StakingPayoutViewModel) {
        cellViewModels = viewModel.cellViewModels
        rootView.payoutButton.imageWithTitleView?.title = viewModel.bottomButtonTitle
        rootView.payoutButton.isHidden = viewModel.cellViewModels.isEmpty
        rootView.tableView.reloadData()
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
        cellViewModels.count
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = rootView.tableView.dequeueReusableCellWithType(
            StakingRewardHistoryTableCell.self)!
        let model = cellViewModels[indexPath.row]
        cell.bind(model: model)
        return cell
    }
}

extension StakingRewardPayoutsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension StakingRewardPayoutsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? { nil }
    var verticalSpacingForEmptyState: CGFloat? { 0 }
    var imageForEmptyState: UIImage? { R.image.iconEmptyHistory() }
    var titleForEmptyState: String? { "Your rewards\nwill appear here" }
    var titleColorForEmptyState: UIColor? { R.color.colorLightGray() }
    var titleFontForEmptyState: UIFont? { .p2Paragraph }
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy { .none }
}

extension StakingRewardPayoutsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        cellViewModels.isEmpty
    }
}
