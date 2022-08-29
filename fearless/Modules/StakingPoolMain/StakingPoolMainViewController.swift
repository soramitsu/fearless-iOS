import UIKit
import SoraFoundation

final class StakingPoolMainViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingPoolMainViewLayout

    var keyboardHandler: KeyboardHandler?

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

        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.assetSelectionView.addTarget(
            self,
            action: #selector(selectAssetButtonClicked),
            for: .touchUpInside
        )

        rootView.startStakingButton.addTarget(
            self,
            action: #selector(startStakingButtonClicked),
            for: .touchUpInside
        )

        rootView.walletSelectionButton.addTarget(
            self,
            action: #selector(selectAccountButtonClicked),
            for: .touchUpInside
        )

        rootView.rewardCalculatorView.delegate = self
        rootView.networkInfoView.delegate = self

        rootView.networkInfoView.collectionView.isHidden = true
    }

    @objc private func selectAssetButtonClicked() {
        output.didTapSelectAsset()
    }

    @objc private func startStakingButtonClicked() {
        output.didTapStartStaking()
    }

    @objc private func selectAccountButtonClicked() {
        output.didTapAccountSelection()
    }
}

// MARK: - StakingPoolMainViewInput

extension StakingPoolMainViewController: StakingPoolMainViewInput {
    func didReceiveNetworkInfoViewModels(_ viewModels: [LocalizableResource<NetworkInfoContentViewModel>]) {
        rootView.bind(viewModels: viewModels)
    }

    func didReceiveBalanceViewModel(_ balanceViewModel: BalanceViewModelProtocol) {
        rootView.bind(balanceViewModel: balanceViewModel)
    }

    func didReceiveChainAsset(_ chainAsset: ChainAsset) {
        rootView.bind(chainAsset: chainAsset)
    }

    func didReceiveEstimationViewModel(_ viewModel: StakingEstimationViewModel) {
        rootView.bind(estimationViewModel: viewModel)
    }

    func didReceiveNominatorStateViewModel(_ viewModel: LocalizableResource<NominationViewModelProtocol>?) {
        rootView.bind(nominatorStateViewModel: viewModel)
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

extension StakingPoolMainViewController: NetworkInfoViewDelegate {
    func animateAlongsideWithInfo(view _: NetworkInfoView) {
        rootView.contentView.scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded: Bool, view _: NetworkInfoView) {
        output.networkInfoViewDidChangeExpansion(isExpanded: isExpanded)
    }
}

extension StakingPoolMainViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - rootView.contentView.frame.maxY

        var contentInsets = rootView.contentView.scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        rootView.contentView.scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let firstResponderView = rootView.rewardCalculatorView
            let fieldFrame = rootView.contentView.scrollView.convert(
                firstResponderView.frame,
                from: firstResponderView.superview
            )

            rootView.contentView.scrollView.scrollRectToVisible(fieldFrame, animated: true)
        }
    }
}
