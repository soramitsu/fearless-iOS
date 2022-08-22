import UIKit
import SoraFoundation

final class StakingPoolMainViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingPoolMainViewLayout

    // MARK: Private properties

    private let output: StakingPoolMainViewOutput

    // MARK: - Constructor

    init(
        output: StakingPoolMainViewOutput,
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
        view = StakingPoolMainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.assetSelectionView.addTarget(
            self,
            action: #selector(actionAssetSelection),
            for: .touchUpInside
        )

        rootView.rewardCalculatorView.delegate = self
    }

    @objc func actionAssetSelection() {
        output.performAssetSelection()
    }
}

// MARK: - StakingPoolMainViewInput

extension StakingPoolMainViewController: StakingPoolMainViewInput {
    func didReceiveBalanceViewModel(_ balanceViewModel: BalanceViewModelProtocol) {
        rootView.bind(balanceViewModel: balanceViewModel)
    }

    func didReceiveChainAsset(_ chainAsset: ChainAsset) {
        rootView.bind(chainAsset: chainAsset)
    }

    func didReceiveEstimationViewModel(_ viewModel: StakingEstimationViewModel) {
        rootView.bind(estimationViewModel: viewModel)
    }
}

// MARK: - Localizable

extension StakingPoolMainViewController: Localizable {
    func applyLocalization() {}
}

extension StakingPoolMainViewController: RewardCalculatorViewDelegate {
    func rewardCalculatorView(_: StakingRewardCalculatorView, didChange amount: Decimal?) {
        output.updateAmount(amount ?? 0.0)
    }

    func rewardCalculatorView(_: StakingRewardCalculatorView, didSelect percentage: Float) {
        output.selectAmountPercentage(percentage)
    }

    func rewardCalculatorDidRequestInfo(_: StakingRewardCalculatorView) {
        output.performRewardInfoAction()
    }
}
