import UIKit
import SoraFoundation

final class StakingPayoutConfirmationViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingPayoutConfirmationViewLayout

    let presenter: StakingPayoutConfirmationPresenterProtocol

    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var viewModel: [LocalizableResource<PayoutConfirmViewModel>] = []

    init(
        presenter: StakingPayoutConfirmationPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingPayoutConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupInitialFeeView()
        applyLocalization()
        setupTable()
        presenter.setup()
    }

    // MARK: - Private functions

    @objc private func confirmAction() {
        presenter.proceed()
    }

    @objc
    private func presentPayoutOptionsAction() {}

    private func setupInitialFeeView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = ExtrinisicConfirmViewModel(
            title: R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages),
            amount: "",
            price: nil,
            icon: nil,
            action: R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages),
            numberOfLines: 1,
            shouldAllowAction: true
        )

        rootView.payoutConfirmView.bind(viewModel: viewModel)

        rootView.payoutConfirmView.actionButton
            .addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
    }

    private func setupTable() {
        rootView.tableView.registerClassesForCell([
            AccountInfoTableViewCell.self,
            StakingPayoutRewardTableCell.self,
            StakingPayoutLabelTableCell.self
        ])

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.allowsSelection = false
    }

    private func lastAccountInfoIndex() -> Int? {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        return viewModel.lastIndex { item in
            if case .accountInfo = item.value(for: locale) {
                return true
            } else {
                return false
            }
        }
    }
}

// MARK: - Localizible

extension StakingPayoutConfirmationViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        setupTitleLocalization(locale)
        setupConfirmViewLocalization(locale)
    }

    private func setupTitleLocalization(_ locale: Locale) {
        title = R.string.localizable.commonConfirmTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupConfirmViewLocalization(_ locale: Locale) {
        guard let feeViewModel = feeViewModel?.value(for: locale) else { return }

        let viewModel = ExtrinisicConfirmViewModel(
            title: R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages),
            amount: feeViewModel.amount,
            price: feeViewModel.price,
            icon: nil,
            action: R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages),
            numberOfLines: 1,
            shouldAllowAction: true
        )

        rootView.payoutConfirmView.bind(viewModel: viewModel)
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
            view.setNeedsLayout()
        }
    }
}

// MARK: - UITableViewDataSource

extension StakingPayoutConfirmationViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch viewModel[indexPath.row].value(for: locale) {
        case let .rewardAmountViewModel(viewModel):
            let cell = tableView.dequeueReusableCellWithType(
                StakingPayoutRewardTableCell.self)!
            cell.bind(
                model: viewModel
            )
            return cell

        case let .accountInfo(viewModel):
            let cell = tableView.dequeueReusableCellWithType(
                AccountInfoTableViewCell.self)!
            cell.delegate = self
            cell.bind(model: viewModel)
            return cell

        case let .restakeDestination(viewModel):
            let cell = tableView.dequeueReusableCellWithType(StakingPayoutLabelTableCell.self)!
            cell.bind(model: viewModel)
            return cell
        }
    }
}

extension StakingPayoutConfirmationViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        switch viewModel[indexPath.row].value(for: locale) {
        case .accountInfo:
            return lastAccountInfoIndex() == indexPath.row ? 82 : 66.0
        default:
            return 48.0
        }
    }
}

// MARK: - StakingPayoutConfirmationViewProtocol

extension StakingPayoutConfirmationViewController: StakingPayoutConfirmationViewProtocol {
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.feeViewModel = feeViewModel
        let locale = localizationManager?.selectedLocale ?? Locale.current
        setupConfirmViewLocalization(locale)
    }

    func didRecieve(viewModel: [LocalizableResource<PayoutConfirmViewModel>]) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
    }
}

extension StakingPayoutConfirmationViewController: AccountInfoTableViewCellDelegate {
    func accountInfoCellDidReceiveAction(_ cell: AccountInfoTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard case let .accountInfo(viewModel) = viewModel[indexPath.row]
            .value(for: locale) else {
            return
        }

        presenter.presentAccountOptions(for: viewModel)
    }
}
