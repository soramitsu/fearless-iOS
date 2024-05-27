import UIKit
import SoraFoundation

final class ClaimCrowdloanRewardsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ClaimCrowdloanRewardsViewLayout

    // MARK: Private properties

    private let output: ClaimCrowdloanRewardsViewOutput

    // MARK: - Constructor

    init(
        output: ClaimCrowdloanRewardsViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = ClaimCrowdloanRewardsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonClicked()
        }
        rootView.networkFeeFooterView.actionButton.addAction { [weak self] in
            self?.output.confirmButtonClicked()
        }
    }
}

// MARK: - ClaimCrowdloanRewardsViewInput

extension ClaimCrowdloanRewardsViewController: ClaimCrowdloanRewardsViewInput {
    func didReceiveVestingViewModel(_ viewModel: BalanceViewModelProtocol?) {
        rootView.lockedRewardsView.bindBalance(viewModel: viewModel)
    }

    func didReceiveBalanceViewModel(_ viewModel: BalanceViewModelProtocol?) {
        rootView.transerableBalanceView.bindBalance(viewModel: viewModel)
    }

    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?) {
        rootView.feeView.bindBalance(viewModel: feeViewModel)
    }

    func didReceiveStakeAmountViewModel(_ stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>) {
        rootView.stakeAmountView.bind(viewModel: stakeAmountViewModel.value(for: selectedLocale))
    }

    func didReceiveHintViewModel(_ hintViewModel: DetailsTriangularedAttributedViewModel?) {
        rootView.bind(hintViewModel: hintViewModel)
    }
}

// MARK: - Localizable

extension ClaimCrowdloanRewardsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
