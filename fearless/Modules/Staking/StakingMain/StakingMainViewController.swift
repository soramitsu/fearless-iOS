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
    @IBOutlet private var headerView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconButton: RoundedButton!
    @IBOutlet private var iconButtonWidth: NSLayoutConstraint!

    private var networkInfoContainerView: UIView!
    private var networkInfoView: NetworkInfoView!

    private var stateContainerView: UIView?
    private var stateView: LocalizableView?

    var iconGenerator: IconGenerating?
    var uiFactory: UIFactoryProtocol?
    var amountFormatterFactory: NumberFormatterFactoryProtocol?

    var keyboardHandler: KeyboardHandler?

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        setupNetworkInfoView()
        setupLocalization()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        networkInfoView.didAppearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didAppearSkeleton()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()

        networkInfoView.didDisappearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didDisappearSkeleton()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        networkInfoView.didUpdateSkeletonLayout()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didUpdateSkeletonLayout()
        }
    }

    @IBAction func actionIcon() {
        presenter.performAccountAction()
    }

    // MARK: - Private functions

    private func setupNetworkInfoView() {
        guard
            let networkInfoView = R.nib.networkInfoView(owner: self),
            let headerIndex = stackView.arrangedSubviews.firstIndex(of: headerView) else { return }

        self.networkInfoView = networkInfoView

        networkInfoView.delegate = self

        networkInfoContainerView = UIView()
        networkInfoContainerView.translatesAutoresizingMaskIntoConstraints = false

        networkInfoContainerView.addSubview(networkInfoView)

        applyConstraints(for: networkInfoContainerView, innerView: networkInfoView)

        stackView.insertArrangedSubview(networkInfoContainerView, at: headerIndex + 1)

        configureStoriesView()
    }

    private func configureStoriesView() {
        networkInfoView.collectionView.backgroundView = nil
        networkInfoView.collectionView.backgroundColor = UIColor.clear

        networkInfoView.collectionView.dataSource = self
        networkInfoView.collectionView.delegate = self

        networkInfoView.collectionView.register(
            UINib(resource: R.nib.storiesCollectionItem),
            forCellWithReuseIdentifier: R.reuseIdentifier.storiesCollectionItemId.identifier)
    }

    private func clearStateView() {
        if let containerView = stateContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()
        }

        stateContainerView = nil
        stateView = nil
    }

    private func applyConstraints(for containerView: UIView, innerView: UIView) {
        innerView.translatesAutoresizingMaskIntoConstraints = false
        innerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                           constant: UIConstants.horizontalInset).isActive = true
        innerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor,
                                            constant: -UIConstants.horizontalInset).isActive = true
        innerView.topAnchor.constraint(equalTo: containerView.topAnchor,
                                       constant: Constants.verticalSpacing).isActive = true

        containerView.bottomAnchor.constraint(equalTo: innerView.bottomAnchor,
                                              constant: Constants.bottomInset).isActive = true
    }

    private func setupNibStateView<T: LocalizableView>(for viewFactory: () -> T?) -> T? {
        clearStateView()

        guard let prevViewIndex = stackView.arrangedSubviews
                .firstIndex(of: networkInfoContainerView) else {
            return nil
        }

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        guard let stateView = viewFactory() else {
            return nil
        }

        containerView.addSubview(stateView)

        applyConstraints(for: containerView, innerView: stateView)

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
        nominationView?.delegate = self
        nominationView?.bind(viewModel: viewModel)
    }

    private func applyBonded(viewModel: StakingEstimationViewModel) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
    }

    private func applyNoStash(viewModel: StakingEstimationViewModel) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
        scrollView.layoutIfNeeded()
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

        networkInfoView.locale = locale
        stateView?.locale = locale
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
    func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?) {
        networkInfoView.bind(viewModel: viewModel)
    }

    func didReceiveChainName(chainName newChainName: LocalizableResource<String>) {
        networkInfoView.bind(chainName: newChainName)
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

extension StakingMainViewController: NetworkInfoViewDelegate {
    func animateAlongsideWithInfo(view: NetworkInfoView) {
        scrollView.layoutIfNeeded()
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

// MARK: Nomination View Delegate -
extension StakingMainViewController: NominationViewDelegate {

    func nominationViewDidReceiveMoreAction(_ nominationView: NominationView) {
        presenter.performManageStakingAction()
    }

    func nominationViewDidReceiveStatusAction(_ nominationView: NominationView) {
        presenter.performNominationStatusAction()
    }
}

extension StakingMainViewController: HiddableBarWhenPushed {}
