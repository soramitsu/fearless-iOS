import UIKit
import FearlessUtils
import SoraFoundation
import SoraUI
import CommonWallet

final class StakingMainViewController: UIViewController, AdaptiveDesignable {
    private enum Constants {
        static let delegationRowHeight: CGFloat = 175.0
        static let verticalSpacing: CGFloat = 0.0
        static let bottomInset: CGFloat = 8.0
        static let contentInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
    }

    var presenter: StakingMainPresenterProtocol?

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var headerView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconButton: RoundedButton!
    @IBOutlet private var iconButtonWidth: NSLayoutConstraint!

    let assetSelectionContainerView = UIView()
    let assetSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        view.borderWidth = 0.0
        return view
    }()

    private var networkInfoContainerView: UIView!
    private var networkInfoView: NetworkInfoView!
    private lazy var alertsContainerView = UIView()
    private lazy var alertsView = AlertsView()
    private lazy var analyticsContainerView = UIView()
    private lazy var tableViewContainer = UIView()
    private lazy var analyticsView = RewardAnalyticsWidgetView()
    private lazy var actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    private var stateContainerView: UIView?
    private var stateView: LocalizableView?
    private lazy var tableView: SelfSizingTableView = {
        let tableView = SelfSizingTableView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.clear
        return tableView
    }()

    private lazy var storiesModel: LocalizableResource<StoriesModel> = StoriesFactory.createModel()

    private var balanceViewModel: LocalizableResource<String>?
    private var assetIconViewModel: ImageViewModelProtocol?
    private var delegationViewModels: [DelegationInfoCellModel]?

    var iconGenerator: IconGenerating?
    var uiFactory: UIFactoryProtocol?
    var amountFormatterFactory: AssetBalanceFormatterFactoryProtocol?

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAssetSelectionView()
        setupNetworkInfoView()
        setupAlertsView()
        setupAnalyticsView()
        setupTableViewLayout()
        setupTableView()
        setupActionButton()
        setupLocalization()
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
        analyticsView.didAppearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didAppearSkeleton()
        }

        presenter?.setup()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()

        networkInfoView.didDisappearSkeleton()
        analyticsView.didDisappearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didDisappearSkeleton()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        networkInfoView.didUpdateSkeletonLayout()
        analyticsView.didUpdateSkeletonLayout()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didUpdateSkeletonLayout()
        }
    }

    @IBAction func actionIcon() {
        presenter?.performAccountAction()
    }

    // MARK: - Private functions

    private func setupAssetSelectionView() {
        assetSelectionContainerView.translatesAutoresizingMaskIntoConstraints = false

        let backgroundView = TriangularedBlurView()
        assetSelectionContainerView.addSubview(backgroundView)
        assetSelectionContainerView.addSubview(assetSelectionView)

        applyConstraints(for: assetSelectionContainerView, innerView: assetSelectionView)

        stackView.insertArranged(view: assetSelectionContainerView, after: headerView)

        assetSelectionView.snp.makeConstraints { make in
            make.height.equalTo(48.0)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(assetSelectionView)
        }

        assetSelectionView.addTarget(
            self,
            action: #selector(actionAssetSelection),
            for: .touchUpInside
        )
    }

    private func setupNetworkInfoView() {
        let networkInfoView = NetworkInfoView()
        networkInfoView.descriptionLabel.isHidden = true

        self.networkInfoView = networkInfoView

        networkInfoView.delegate = self

        networkInfoContainerView = UIView()
        networkInfoContainerView.translatesAutoresizingMaskIntoConstraints = false

        networkInfoContainerView.addSubview(networkInfoView)

        applyConstraints(for: networkInfoContainerView, innerView: networkInfoView)

        stackView.insertArranged(view: networkInfoContainerView, after: assetSelectionContainerView)

        configureStoriesView()
    }

    private func setupAlertsView() {
        alertsContainerView.translatesAutoresizingMaskIntoConstraints = false
        alertsContainerView.addSubview(alertsView)

        applyConstraints(for: alertsContainerView, innerView: alertsView)

        stackView.addArrangedSubview(alertsContainerView)

        alertsView.delegate = self
    }

    private func setupAnalyticsView() {
        analyticsContainerView.translatesAutoresizingMaskIntoConstraints = false
        analyticsContainerView.addSubview(analyticsView)

        applyConstraints(for: analyticsContainerView, innerView: analyticsView)

        stackView.addArrangedSubview(analyticsContainerView)
        analyticsView.snp.makeConstraints { $0.height.equalTo(228) }
        analyticsView.backgroundButton.addTarget(self, action: #selector(handleAnalyticsWidgetTap), for: .touchUpInside)
    }

    @objc
    private func handleAnalyticsWidgetTap() {
        presenter?.performAnalyticsAction()
    }

    private func configureStoriesView() {
        networkInfoView.collectionView.backgroundView = nil
        networkInfoView.collectionView.backgroundColor = UIColor.clear

        networkInfoView.collectionView.dataSource = self
        networkInfoView.collectionView.delegate = self

        networkInfoView.collectionView.register(
            UINib(resource: R.nib.storiesPreviewCollectionItem),
            forCellWithReuseIdentifier: R.reuseIdentifier.storiesPreviewCollectionItemId.identifier
        )
    }

    private func clearStateView() {
        if let containerView = stateContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()
        }

        stateContainerView = nil
        stateView = nil
        alertsContainerView.isHidden = true
        analyticsContainerView.isHidden = true
    }

    private func applyConstraints(for containerView: UIView, innerView: UIView) {
        innerView.translatesAutoresizingMaskIntoConstraints = false
        innerView.leadingAnchor.constraint(
            equalTo: containerView.leadingAnchor,
            constant: UIConstants.horizontalInset
        ).isActive = true
        innerView.trailingAnchor.constraint(
            equalTo: containerView.trailingAnchor,
            constant: -UIConstants.horizontalInset
        ).isActive = true
        innerView.topAnchor.constraint(
            equalTo: containerView.topAnchor,
            constant: Constants.verticalSpacing
        ).isActive = true

        containerView.bottomAnchor.constraint(
            equalTo: innerView.bottomAnchor,
            constant: Constants.bottomInset
        ).isActive = true
    }

    private func setupView<T: LocalizableView>(for viewFactory: () -> T?) -> T? {
        clearStateView()

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        guard let stateView = viewFactory() else {
            return nil
        }

        containerView.addSubview(stateView)

        applyConstraints(for: containerView, innerView: stateView)

        stackView.addArrangedSubview(containerView)

        stateContainerView = containerView
        self.stateView = stateView

        stackView.removeArrangedSubview(tableViewContainer)
        stackView.addArrangedSubview(tableViewContainer)

        return stateView
    }

    private func setupRewardEstimationViewIfNeeded() -> RewardEstimationView? {
        changeActionButtonVisibility(true)

        if let rewardView = stateView as? RewardEstimationView {
            return rewardView
        }

        let stateView = setupView { R.nib.rewardEstimationView(owner: nil) }

        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current
        stateView?.uiFactory = uiFactory
        stateView?.amountFormatterFactory = amountFormatterFactory
        stateView?.delegate = self

        return stateView
    }

    private func setupNominatorViewIfNeeded() -> NominatorStateView? {
        if let nominatorView = stateView as? NominatorStateView {
            return nominatorView
        }

        let stateView = setupView { NominatorStateView() }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func setupValidatorViewIfNeeded() -> ValidatorStateView? {
        if let validator = stateView as? ValidatorStateView {
            return validator
        }

        let stateView = setupView { ValidatorStateView() }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func setupTableViewLayout() {
        tableViewContainer.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().offset(Constants.verticalSpacing)
            make.bottom.equalToSuperview().inset(Constants.bottomInset)
        }

        stackView.addArrangedSubview(tableViewContainer)
    }

    private func setupTableView() {
        tableView.allowsSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UIConstants.cellHeight
        tableView.registerClassForCell(DelegationInfoCell.self)
    }

    private func setupActionButton() {
        view.addSubview(actionButton)
        actionButton.addTarget(self, action: #selector(actionButtonClicked), for: .touchUpInside)
        actionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
        }
    }

    @objc
    private func actionButtonClicked() {
        presenter?.performMainAction()
    }

    private func applyNominator(viewModel: LocalizableResource<NominationViewModelProtocol>) {
        let nominatorView = setupNominatorViewIfNeeded()
        nominatorView?.delegate = self
        nominatorView?.bind(viewModel: viewModel)
    }

    private func applyNoStash(viewModel: StakingEstimationViewModel) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
        scrollView.layoutIfNeeded()
    }

    private func applyValidator(viewModel: LocalizableResource<ValidationViewModelProtocol>) {
        let validatorView = setupValidatorViewIfNeeded()
        validatorView?.delegate = self
        validatorView?.bind(viewModel: viewModel)
    }

    private func applyRewards(viewModel: StakingEstimationViewModel) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
    }

    private func applyDelegations(viewModels: [DelegationInfoCellModel]?) {
        delegationViewModels = viewModels
        delegationViewModels?.forEach { model in
            model.delegate = self
        }
        tableView.reloadData()
    }

    private func applyAlerts(_ alerts: [StakingAlert]) {
        alertsContainerView.isHidden = alerts.isEmpty
        alertsView.bind(alerts: alerts)
        alertsContainerView.setNeedsLayout()
    }

    private func applyAnalyticsRewards(viewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?) {
        analyticsContainerView.isHidden = viewModel == nil
        analyticsView.bind(viewModel: viewModel)
    }

    private func changeActionButtonVisibility(_ isVisible: Bool) {
        let insets = scrollView.contentInset
        let bottomInset: CGFloat = isVisible ? 84 : 0

        scrollView.contentInset = UIEdgeInsets(
            top: insets.top,
            left: insets.left,
            bottom: bottomInset,
            right: insets.right
        )

        actionButton.isHidden = !isVisible
    }
}

extension StakingMainViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        titleLabel.text = R.string.localizable
            .tabbarStakingTitle(preferredLanguages: languages)
        actionButton.imageWithTitleView?.title = R.string.localizable
            .stakingStartTitle(preferredLanguages: languages)

        networkInfoView.locale = locale
        stateView?.locale = locale
        alertsView.locale = locale
        analyticsView.locale = locale
        tableView.reloadData()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingMainViewController: RewardEstimationViewDelegate {
    func rewardEstimationView(_: RewardEstimationView, didChange amount: Decimal?) {
        presenter?.updateAmount(amount ?? 0.0)
    }

    func rewardEstimationView(_: RewardEstimationView, didSelect percentage: Float) {
        presenter?.selectAmountPercentage(percentage)
    }

    func rewardEstimationDidRequestInfo(_: RewardEstimationView) {
        presenter?.performRewardInfoAction()
    }
}

extension StakingMainViewController: StakingMainViewProtocol {
    func didReceive(stakingEstimationViewModel: StakingEstimationViewModel) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: stakingEstimationViewModel)
    }

    func didRecieveNetworkStakingInfo(
        viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?
    ) {
        guard networkInfoView != nil else {
            return
        }
        networkInfoView.bind(viewModel: viewModel)
    }

    func didReceive(viewModel: StakingMainViewModel) {
        guard viewIfLoaded != nil else {
            return
        }
        assetIconViewModel?.cancel(on: assetSelectionView.iconView)

        assetIconViewModel = viewModel.assetIcon
        balanceViewModel = viewModel.balanceViewModel

        iconButton.imageWithTitleView?.iconImage = R.image.iconFearlessRounded()
        iconButton.invalidateLayout()

        networkInfoView.bind(chainName: viewModel.chainName)
        assetSelectionView.title = viewModel.assetName
        assetSelectionView.subtitle = viewModel.balanceViewModel?.value(for: selectedLocale)

        assetSelectionView.iconImage = nil

        let iconSize = 2 * assetSelectionView.iconRadius
        assetIconViewModel?.loadImage(
            on: assetSelectionView.iconView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )
    }

    func didReceiveStakingState(viewModel: StakingViewState) {
        guard viewIfLoaded != nil else {
            return
        }

        changeActionButtonVisibility(false)
        if case .delegations = viewModel {
            tableView.isHidden = false
        } else {
            tableView.isHidden = true
            applyDelegations(viewModels: nil)
        }

        switch viewModel {
        case .undefined:
            clearStateView()
        case let .noStash(viewModel, alerts):
            applyNoStash(viewModel: viewModel)
            applyAlerts(alerts)
        case let .nominator(viewModel, alerts, analyticsViewModel):
            applyNominator(viewModel: viewModel)
            applyAlerts(alerts)
            applyAnalyticsRewards(viewModel: analyticsViewModel)
        case let .validator(viewModel, alerts, analyticsViewModel):
            applyValidator(viewModel: viewModel)
            applyAlerts(alerts)
            applyAnalyticsRewards(viewModel: analyticsViewModel)
        case let .delegations(rewardViewModel, delegationViewModels, alerts, analyticsViewModel):
            applyDelegations(viewModels: delegationViewModels)
            applyRewards(viewModel: rewardViewModel)
            applyAlerts(alerts)
            applyAnalyticsRewards(viewModel: analyticsViewModel)
        }
    }

    func expandNetworkInfoView(_ isExpanded: Bool) {
        networkInfoView.setExpanded(isExpanded, animated: false)
    }

    @objc func actionAssetSelection() {
        presenter?.performAssetSelection()
    }
}

extension StakingMainViewController: NetworkInfoViewDelegate {
    func animateAlongsideWithInfo(view _: NetworkInfoView) {
        scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded: Bool, view _: NetworkInfoView) {
        presenter?.networkInfoViewDidChangeExpansion(isExpanded: isExpanded)
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
            let fieldFrame = scrollView.convert(
                firstResponderView.frame,
                from: firstResponderView.superview
            )

            scrollView.scrollRectToVisible(fieldFrame, animated: true)
        }
    }
}

// MARK: Collection View Data Source -

extension StakingMainViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        storiesModel.value(for: selectedLocale).stories.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: R.reuseIdentifier.storiesPreviewCollectionItemId,
            for: indexPath
        )!

        let model = storiesModel.value(for: selectedLocale)
        let story = model.stories[indexPath.row]

        cell.bind(icon: story.icon, caption: story.title)
        return cell
    }
}

// MARK: Collection View Delegate -

extension StakingMainViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        presenter?.selectStory(at: indexPath.row)
    }
}

// MARK: - StakingStateViewDelegate

extension StakingMainViewController: DelegationInfoCellModelDelegate {
    func didReceiveMoreAction(delegationInfo: ParachainStakingDelegationInfo) {
        presenter?.performParachainManageStakingAction(for: delegationInfo)
    }

    func didReceiveStatusAction() {
        presenter?.performDelegationStatusAction()
    }
}

extension StakingMainViewController: StakingStateViewDelegate {
    func stakingStateViewDidReceiveMoreAction(_: StakingStateView) {
        presenter?.performManageStakingAction()
    }

    func stakingStateViewDidReceiveStatusAction(_ view: StakingStateView) {
        if view is NominatorStateView {
            presenter?.performNominationStatusAction()
        } else if view is ValidatorStateView {
            presenter?.performValidationStatusAction()
        }
    }
}

extension StakingMainViewController: HiddableBarWhenPushed {}

extension StakingMainViewController: AlertsViewDelegate {
    func didSelectStakingAlert(_ alert: StakingAlert) {
        switch alert {
        case .nominatorChangeValidators, .nominatorAllOversubscribed:
            presenter?.performChangeValidatorsAction()
        case .bondedSetValidators:
            presenter?.performSetupValidatorsForBondedAction()
        case .nominatorLowStake:
            presenter?.performBondMoreAction()
        case .redeemUnbonded:
            presenter?.performRedeemAction()
        case let .collatorLeaving(_, delegation):
            presenter?.performParachainManageStakingAction(for: delegation)
        case let .collatorLowStake(_, delegation):
            presenter?.performParachainManageStakingAction(for: delegation)
        case let .parachainRedeemUnbonded(delegation):
            presenter?.performParachainManageStakingAction(for: delegation)
        case .waitingNextEra:
            break
        }
    }
}

extension StakingMainViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        delegationViewModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCellWithType(DelegationInfoCell.self),
            let viewModel = delegationViewModels?[indexPath.row]
        else {
            return UITableViewCell()
        }
        viewModel.locale = selectedLocale
        cell.bind(to: viewModel)
        return cell
    }
}

extension StakingMainViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.delegationRowHeight
    }
}
