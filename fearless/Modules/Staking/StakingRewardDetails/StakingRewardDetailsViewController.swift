import UIKit
import SoraFoundation

final class StakingRewardDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardDetailsViewLayout

    let presenter: StakingRewardDetailsPresenterProtocol

    init(
        presenter: StakingRewardDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    private var rows: [RewardDetailsRow] = []
    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingRewardDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupTable()
        setupPayoutButtonAction()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassesForCell([
            StakingPayoutStatusTableCell.self,
            StakingPayoutLabelTableCell.self,
            StakingPayoutRewardTableCell.self,
            AccountInfoTableViewCell.self
        ])
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

extension StakingRewardDetailsViewController: StakingRewardDetailsViewProtocol {
    func reload(with viewModel: LocalizableResource<StakingRewardDetailsViewModel>) {
        rows = viewModel.value(for: selectedLocale).rows
        rootView.tableView.reloadData()
    }
}

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
        title = R.string.localizable.stakingRewardDetailsTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupButtonLocalization() {
        let title = R.string.localizable.stakingRewardDetailsPayout(preferredLanguages: selectedLocale.rLanguages)
        rootView.payoutButton.imageWithTitleView?.title = title
    }
}

extension StakingRewardDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension StakingRewardDetailsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case let .status(status):
            let cell = tableView.dequeueReusableCellWithType(
                StakingPayoutStatusTableCell.self)!
            cell.bind(model: status)
            return cell
        case let .date(dateViewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingPayoutLabelTableCell.self)!
            cell.bind(model: dateViewModel)
            return cell
        case let .era(eraViewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingPayoutLabelTableCell.self)!
            cell.bind(model: eraViewModel)
            return cell
        case let .reward(rewardViewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingPayoutRewardTableCell.self)!
            cell.bind(model: rewardViewModel)
            return cell
        case let .validatorInfo(model):
            let cell = tableView.dequeueReusableCellWithType(
                AccountInfoTableViewCell.self)!
            cell.delegate = self
            cell.bind(model: model)
            return cell
        default:
            return UITableViewCell()
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch rows[indexPath.row] {
        case .validatorInfo:
            return 82.0
        default:
            return 48.0
        }
    }
}

extension StakingRewardDetailsViewController: AccountInfoTableViewCellDelegate {
    func accountInfoCellDidReceiveAction(_: AccountInfoTableViewCell) {
        presenter.handleValidatorAccountAction(locale: selectedLocale)
    }
}
