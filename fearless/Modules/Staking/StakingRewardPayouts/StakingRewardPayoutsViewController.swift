import UIKit
import SoraFoundation

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
        let title = R.string.localizable.stakingRewardPayoutsPayoutAll("0.00345 KSM")
        rootView.payoutButton.imageWithTitleView?.title = title
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(StakingRewardHistoryTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func setupPayoutButtonAction() {
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

    func showEmptyView() {
        rootView.payoutButton.isHidden = true
        rootView.emptyImageView.isHidden = false
        rootView.emptyLabel.isHidden = false
    }

    func hideEmptyView() {
        rootView.payoutButton.isHidden = false
        rootView.emptyImageView.isHidden = true
        rootView.emptyLabel.isHidden = true
    }

    func reloadTable(with cellViewModels: [StakingRewardHistoryCellViewModel]) {
        self.cellViewModels = cellViewModels
        rootView.tableView.reloadData()
    }

    func startLoading() {
        rootView.activityIndicatorView.startAnimating()
        rootView.payoutButton.isHidden = true
    }

    func stopLoading() {
        rootView.activityIndicatorView.stopAnimating()
        rootView.payoutButton.isHidden = false
    }
}

extension StakingRewardPayoutsViewController: Localizable {
    private func setupLocalization() {
        setupTitleLocalization()
        setupButtonLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingRewardPayoutsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.handleSelectedHistory(at: indexPath)
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
