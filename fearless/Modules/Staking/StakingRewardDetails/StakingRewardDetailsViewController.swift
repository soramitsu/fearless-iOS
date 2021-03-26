import UIKit
import SoraFoundation

final class StakingRewardDetailsViewController: UIViewController, ViewHolder {

    typealias RootViewType = StakingRewardDetailsViewLayout

    let presenter: StakingRewardDetailsPresenterProtocol
    let localizationManager: LocalizationManagerProtocol?

    init(
        presenter: StakingRewardDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingRewardDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassesForCell([
            StakingRewardDetailsStatusTableCell.self,
            StakingRewardDetailsLabelTableCell.self,
            StakingRewardDetailsRewardTableCell.self,
            AccountInfoTableViewCell.self
        ])
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

extension StakingRewardDetailsViewController: StakingRewardDetailsViewProtocol {}

extension StakingRewardDetailsViewController: Localizable {

    private func setupLocalization() {
        setupTitleLocalization()
        setupButtonLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
            view.setNeedsLayout()
        }
    }

    private func setupTitleLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        title = R.string.localizable.stakingRewardDetailsTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupButtonLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let title = R.string.localizable.stakingRewardDetailsPayout(preferredLanguages: locale.rLanguages)
        rootView.payoutButton.imageWithTitleView?.title = title
    }
}

extension StakingRewardDetailsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // TODO FLW-677
    }
}

extension StakingRewardDetailsViewController: UITableViewDataSource {

    // TODO delete stub data
    var stubCellData: [RewardDetailsRow] {
        let locale = localizationManager?.selectedLocale
        let rewardStatus = StakingRewardStatus.claimable
        let statusViewModel = StakingRewardStatusViewModel(
            title: R.string.localizable.stakingRewardDetailsStatus(preferredLanguages: locale?.rLanguages),
            statusText: rewardStatus.titleForLocale(locale),
            icon: rewardStatus.icon)

        return [
            .status(statusViewModel),
            .date(.init(
                    titleText: R.string.localizable.stakingRewardDetailsDate(),
                    valueText: "3 March 2020")),
            .era(.init(
                    titleText: R.string.localizable.stakingRewardDetailsEra(),
                    valueText: "#1690")),
            .reward(.init(ksmAmountText: "0.00005 KSM", usdAmountText: "$0,01")),
            .validatorInfo(.init(
                            name: "Validator",
                            address: "✨👍✨ Day7 ✨👍✨",
                            icon: R.image.iconAccount())),
            .validatorInfo(.init(
                            name: "Payout account",
                            address: "🐟 ANDREY",
                            icon: R.image.iconAccount()))
        ]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stubCellData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // TODO handle current locale
        switch stubCellData[indexPath.row] {
        case .status(let status):
            let cell = tableView.dequeueReusableCellWithType(
                StakingRewardDetailsStatusTableCell.self)!
            cell.bind(model: status)
            return cell
        case .date(let dateViewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingRewardDetailsLabelTableCell.self)!
            cell.bind(model: dateViewModel)
            return cell
        case .era(let eraViewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingRewardDetailsLabelTableCell.self)!
            cell.bind(model: eraViewModel)
            return cell
        case .reward(let rewardViewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingRewardDetailsRewardTableCell.self)!
            cell.bind(model: rewardViewModel)
            return cell
        case .validatorInfo(let model):
            let cell = tableView.dequeueReusableCellWithType(
                AccountInfoTableViewCell.self)!
            cell.bind(model: model)
            return cell
        }
    }
}
