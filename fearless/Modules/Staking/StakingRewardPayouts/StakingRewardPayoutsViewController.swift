import UIKit
import SoraFoundation

final class StakingRewardPayoutsViewController: UIViewController, ViewHolder {

    typealias RootViewType = StakingRewardPayoutsViewLayout

    // MARK: Properties -
    let presenter: StakingRewardPayoutsPresenterProtocol

    // MARK: Init -
    init(presenter: StakingRewardPayoutsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
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
        presenter.setup()
    }

    private func setupTitleLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.stakingRewardPayoutsTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(StakingRewardHistoryTableCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: StakingRewardHistoryHeaderView.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

extension StakingRewardPayoutsViewController: StakingRewardPayoutsViewProtocol {}

extension StakingRewardPayoutsViewController: Localizable {

    private func setupLocalization() {
        setupTitleLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingRewardPayoutsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: StakingRewardHistoryHeaderView = tableView.dequeueReusableHeaderFooterView()
        let model = "FEB 1, 2021 (ERA #1,685)"
        headerView.bind(model: model)
        return headerView
    }
}

extension StakingRewardPayoutsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        10
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = rootView.tableView.dequeueReusableCellWithType(StakingRewardHistoryTableCell.self)!
        let model = StakingRewardHistoryTableCell.Model(
            addressOrName: "SORAMITSU",
            daysLeftText: "2 days left",
            ksmAmountText: "+0.012 KSM",
            usdAmountText: "$1.4")
        cell.bind(model: model)
        return cell
    }
}
