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
        setupPayoutButtonAction()
        presenter.setup()
    }

    private func setupTitleLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.stakingRewardPayoutsTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupButtonLocalization() {
        // TODO
        let title = R.string.localizable.stakingRewardPayoutsPayoutAll("0.00345 KSM")
        rootView.payoutButton.imageWithTitleView?.title = title
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(StakingRewardHistoryTableCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: StakingRewardHistoryHeaderView.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func setupPayoutButtonAction() {
        rootView.payoutButton.addTarget(
            self,
            action: #selector(handlePayoutButtonAction),
            for: .touchUpInside)
    }

    @objc
    private func handlePayoutButtonAction() {
        presenter.handlePayoutAction()
    }
}

extension StakingRewardPayoutsViewController: StakingRewardPayoutsViewProtocol {}

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

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: StakingRewardHistoryHeaderView = tableView.dequeueReusableHeaderFooterView()
        let model = stubCellData[section].0
        headerView.bind(model: model)
        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.handleSelectedHistory()
    }
}

extension StakingRewardPayoutsViewController: UITableViewDataSource {

    // TODO delete stub data
    var stubCellData: [(String, [StakingRewardHistoryTableCell.ViewModel])] {
        [
            ("DEC 15, 2021 (era #1,615)".uppercased(), [
                .init(
                    addressOrName: "SORAMITSU",
                    daysLeftText: "2 days left",
                    ksmAmountText: "+0.012 KSM",
                    usdAmountText: "$1.4"
                )
            ]),
            ("Feb 1, 2021 (era #1,685)".uppercased(), [
                .init(
                    addressOrName: "SORAMITSU",
                    daysLeftText: "16 days left",
                    ksmAmountText: "+0.012 KSM",
                    usdAmountText: "$1.4"
                )
            ]),
            ("Feb 2, 2021 (era #1,688)".uppercased(), [
                .init(
                    addressOrName: "✨👍✨ Day7 ✨👍✨",
                    daysLeftText: "17 days left",
                    ksmAmountText: "+0.002 KSM",
                    usdAmountText: "$0.3"
                ),
                .init(
                    addressOrName: "✨👍✨ Day7 ✨👍✨ aaaa aaaa aaaa aaa",
                    daysLeftText: "17 days left",
                    ksmAmountText: "+0.002 KSM",
                    usdAmountText: "$0.3"
                )
            ])
        ]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return stubCellData.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stubCellData[section].1.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = rootView.tableView.dequeueReusableCellWithType(
            StakingRewardHistoryTableCell.self)!
        let model = stubCellData[indexPath.section].1[indexPath.row]
        cell.bind(model: model)
        return cell
    }
}
