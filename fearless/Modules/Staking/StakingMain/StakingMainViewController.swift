import UIKit
import FearlessUtils
import SoraFoundation
import SoraUI
import CommonWallet

final class StakingMainViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let verticalSpacing: CGFloat = 0.0
        static let bottomInset: CGFloat = 8.0
    }

    var presenter: StakingMainPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconButton: RoundedButton!
    @IBOutlet private var iconButtonWidth: NSLayoutConstraint!

    @IBOutlet weak var networkView: UIView!

    @IBOutlet weak var networkInfoContainer: UIView!
    @IBOutlet weak var titleControl: ActionTitleControl!
    @IBOutlet weak var storiesView: UICollectionView!
    @IBOutlet weak var storiesViewZeroHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var totalStakedTitleLabel: UILabel!
    @IBOutlet weak var totalStakedAmountLabel: UILabel!
    @IBOutlet weak var totalStakedFiatAmountLabel: UILabel!
    @IBOutlet weak var minimumStakeTitleLabel: UILabel!
    @IBOutlet weak var minimumStakeAmountLabel: UILabel!
    @IBOutlet weak var minimumStakeFiatAmountLabel: UILabel!
    @IBOutlet weak var activeNominatorsTitleLabel: UILabel!
    @IBOutlet weak var activeNominatorsLabel: UILabel!
    @IBOutlet weak var lockupPeriodTitleLabel: UILabel!
    @IBOutlet weak var lockupPeriodLabel: UILabel!

    private var stateContainerView: UIView?
    private var stateView: LocalizableView?

    var iconGenerator: IconGenerating?
    var uiFactory: UIFactoryProtocol?
    var amountFormatterFactory: NumberFormatterFactoryProtocol?

    var keyboardHandler: KeyboardHandler?

    // MARK: - Private declarations

    private var chainName: String = ""
    private var eraStakingInfo: LocalizableResource<EraStakingInfoViewModelProtocol>?
    private var lockUpPeriod: LocalizableResource<String>?

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
        configureCollectionView()
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

    @IBAction func actionIcon() {
        presenter.performAccountAction()
    }

    @IBAction func toggleNetworkWidgetVisibility(sender: ActionTitleControl) {
        let animationOptions: UIView.AnimationOptions = sender.isActivated ? .curveEaseIn : .curveEaseOut

        self.storiesViewZeroHeightConstraint?.isActive = sender.isActivated
        UIView.animate(
            withDuration: 0.35,
            delay: 0.0,
            options: [animationOptions],
            animations: {
                self.view.layoutIfNeeded()
                self.networkInfoContainer.isHidden = sender.isActivated
            })
    }

    // MARK: - Private functions
    private func configureCollectionView() {
        storiesView.backgroundView = nil
        storiesView.backgroundColor = UIColor.clear

        storiesView.register(UINib(resource: R.nib.storiesCollectionItem),
                             forCellWithReuseIdentifier: R.reuseIdentifier.storiesCollectionItemId.identifier)
    }

    private func applyLockUpPeriod() {
        guard let viewModel = lockUpPeriod else { return }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        lockupPeriodLabel.text = viewModel.value(for: locale)
    }

    private func applyStakingInfo() {
        guard let viewModel = eraStakingInfo else { return }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let localizedViewModel = viewModel.value(for: locale)

        totalStakedAmountLabel.text = localizedViewModel.totalStake?.amount
        totalStakedFiatAmountLabel.text = localizedViewModel.totalStake?.price
        minimumStakeAmountLabel.text = localizedViewModel.minimalStake?.amount
        minimumStakeFiatAmountLabel.text = localizedViewModel.minimalStake?.price
        activeNominatorsLabel.text = localizedViewModel.activeNominators
    }

    private func applyChainName() {
        let languages = (localizationManager?.selectedLocale ?? Locale.current).rLanguages

        titleControl.titleLabel.text = R.string.localizable
            .stakingMainNetworkTitle(chainName, preferredLanguages: languages)
        titleControl.invalidateLayout()
    }

    private func clearStateView() {
        if let containerView = stateContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()
        }

        stateContainerView = nil
        stateView = nil
    }

    private func applyConstraints(for containerView: UIView, stateView: UIView) {
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                           constant: UIConstants.horizontalInset).isActive = true
        stateView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor,
                                            constant: -UIConstants.horizontalInset).isActive = true
        stateView.topAnchor.constraint(equalTo: containerView.topAnchor,
                                       constant: Constants.verticalSpacing).isActive = true

        containerView.bottomAnchor.constraint(equalTo: stateView.bottomAnchor,
                                              constant: Constants.bottomInset).isActive = true
    }

    private func setupNibStateView<T: LocalizableView>(for viewFactory: () -> T?) -> T? {
        clearStateView()

        guard let prevViewIndex = stackView.arrangedSubviews.firstIndex(of: networkView) else {
            return nil
        }

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        guard let stateView = viewFactory() else {
            return nil
        }

        containerView.addSubview(stateView)

        applyConstraints(for: containerView, stateView: stateView)

        stackView.insertArrangedSubview(containerView, at: prevViewIndex + 1)

        self.stateContainerView = containerView
        self.stateView = stateView

        return stateView
    }

    private func setupRewardEstimationViewIfNeeded() -> RewardEstimationView? {
        if let rewardView = stateView as? RewardEstimationView {
            return rewardView
        }

        let stateView = setupNibStateView { R.nib.rewardEstimationView(owner: nil) }

        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current
        stateView?.uiFactory = uiFactory
        stateView?.amountFormatterFactory = amountFormatterFactory
        stateView?.delegate = self

        return stateView
    }

    private func setupNominationViewIfNeeded() -> NominationView? {
        if let nominationView = stateView as? NominationView {
            return nominationView
        }

        let stateView = setupNibStateView { R.nib.nominationView(owner: nil) }

        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func setupValidatorViewIfNeeded() -> ValidationView? {
        if let validationView = stateView as? ValidationView {
            return validationView
        }

        let stateView = setupNibStateView { R.nib.validationView(owner: nil) }

        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func applyNomination(viewModel: LocalizableResource<NominationViewModelProtocol>) {
        let nominationView = setupNominationViewIfNeeded()
        nominationView?.bind(viewModel: viewModel)
    }

    private func applyBonded(viewModel: StakingEstimationViewModelProtocol) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
    }

    private func applyNoStash(viewModel: StakingEstimationViewModelProtocol) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
    }

    private func applyValidator() {
        _ = setupValidatorViewIfNeeded()
    }
}

extension StakingMainViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        titleLabel.text = R.string.localizable
            .tabbarStakingTitle(preferredLanguages: languages)
        totalStakedTitleLabel.text = R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: languages)
        minimumStakeTitleLabel.text = R.string.localizable
            .stakingMainMinimumStakeTitle(preferredLanguages: languages)
        activeNominatorsTitleLabel.text = R.string.localizable
            .stakingMainActiveNominatorsTitle(preferredLanguages: languages)
        lockupPeriodTitleLabel.text = R.string.localizable
            .stakingMainLockupPeriodTitle(preferredLanguages: languages)

        stateView?.locale = locale

        applyChainName()
        applyStakingInfo()
        applyLockUpPeriod()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingMainViewController: RewardEstimationViewDelegate {
    func rewardEstimationView(_ view: RewardEstimationView, didChange amount: Decimal?) {
        presenter.updateAmount(amount ?? 0.0)
    }

    func rewardEstimationView(_ view: RewardEstimationView, didSelect percentage: Float) {
        presenter.selectAmountPercentage(percentage)
    }

    func rewardEstimationDidStartAction(_ view: RewardEstimationView) {
        presenter.performMainAction()
    }
}

extension StakingMainViewController: StakingMainViewProtocol {
    func didReceiveLockupPeriod(_ newPeriod: LocalizableResource<String>) {
        lockUpPeriod = newPeriod
        applyLockUpPeriod()
    }

    func didReceiveEraStakingInfo(viewModel: LocalizableResource<EraStakingInfoViewModelProtocol>) {
        eraStakingInfo = viewModel
        applyStakingInfo()
    }

    func didReceiveChainName(chainName newChainName: LocalizableResource<String>) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        self.chainName = newChainName.value(for: locale)
        applyChainName()
    }

    func didReceive(viewModel: StakingMainViewModelProtocol) {
        let sideSize = iconButtonWidth.constant - iconButton.contentInsets.left
            - iconButton.contentInsets.right
        let size = CGSize(width: sideSize, height: sideSize)
        let icon = try? iconGenerator?.generateFromAddress(viewModel.address)
            .imageWithFillColor(R.color.colorWhite()!, size: size, contentScale: UIScreen.main.scale)
        iconButton.imageWithTitleView?.iconImage = icon
        iconButton.invalidateLayout()
    }

    func didReceiveStakingState(viewModel: StakingViewState) {
        switch viewModel {
        case .undefined:
            clearStateView()
        case .bonded(let viewModel):
            applyBonded(viewModel: viewModel)
        case .noStash(let viewModel):
            applyNoStash(viewModel: viewModel)
        case .nominator(let viewModel):
            applyNomination(viewModel: viewModel)
        case .validator:
            applyValidator()
        }
    }
}

extension StakingMainViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0, let firstResponderView = stateView {
            let fieldFrame = scrollView.convert(firstResponderView.frame,
                                                from: firstResponderView.superview)

            scrollView.scrollRectToVisible(fieldFrame, animated: true)
        }
    }
}

// MARK: Collection View Data Source -
extension StakingMainViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO: FLW-635
        return 4
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: R.reuseIdentifier.storiesCollectionItemId,
            for: indexPath)!

        return cell
    }
}

// MARK: Collection View Delegate -
extension StakingMainViewController: UICollectionViewDelegate {
    // TODO: FLW-635
}
