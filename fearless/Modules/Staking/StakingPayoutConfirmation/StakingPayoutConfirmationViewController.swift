import UIKit
import SoraFoundation

final class StakingPayoutConfirmationViewController: UIViewController, ViewHolder {

    typealias RootViewType = StakingPayoutConfirmationViewLayout

    let presenter: StakingPayoutConfirmationPresenterProtocol
    let localizationManager: LocalizationManagerProtocol?

    init(
        presenter: StakingPayoutConfirmationPresenterProtocol,
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
        view = StakingPayoutConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassesForCell([
            StakingRewardDetailsLabelTableCell.self,
            StakingRewardDetailsRewardTableCell.self,
            AccountInfoTableViewCell.self
        ])
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

extension StakingPayoutConfirmationViewController: StakingPayoutConfirmationViewProtocol {}

extension StakingPayoutConfirmationViewController: Localizable {

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        setupTitleLocalization(locale)
        setupTranformViewLocalization(locale)
    }

    private func setupTitleLocalization(_ locale: Locale) {
        title = R.string.localizable.stakingConfirmTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupTranformViewLocalization(_ locale: Locale) {
        // TODO get viewModel from presenter
        let viewModel = TransferConfirmAccessoryViewModel(
            title: R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages),
            icon: nil,
            action: R.string.localizable.stakingConfirmTitle(preferredLanguages: locale.rLanguages),
            numberOfLines: 1,
            amount: "0.001 KSM",
            shouldAllowAction: true)
        rootView.transferConfirmView.bind(viewModel: viewModel)
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
            view.setNeedsLayout()
        }
    }
}

extension StakingPayoutConfirmationViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // TODO FLW-677
    }
}

extension StakingPayoutConfirmationViewController: UITableViewDataSource {

    // TODO delete stub data
    var stubCellData: [RewardDetailsRow] {
        return [
            .validatorInfo(.init(
                            name: "Validator",
                            address: "✨👍✨ Day7 ✨👍✨",
                            icon: R.image.iconAccount())),
            .validatorInfo(.init(
                            name: "Payout account",
                            address: "🐟 ANDREY",
                            icon: R.image.iconAccount())),
            .destination(.init(
                            titleText: R.string.localizable.stakingRewardDestinationTitle(),
                            valueText: R.string.localizable.stakingRestakeTitle())),
            .era(.init(
                    titleText: R.string.localizable.stakingRewardDetailsEra(),
                    valueText: "#1690")),
            .reward(.init(ksmAmountText: "0.00005 KSM", usdAmountText: "$0,01"))
        ]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stubCellData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // TODO handle current locale
        switch stubCellData[indexPath.row] {
        case .destination(let viewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingRewardDetailsLabelTableCell.self)!
            cell.bind(model: viewModel)
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
        default:
            fatalError()
        }
    }
}
