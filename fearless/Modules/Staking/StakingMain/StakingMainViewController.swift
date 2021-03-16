import UIKit
import FearlessUtils
import SoraFoundation
import SoraUI
import CommonWallet

final class StakingMainViewController: UIViewController, AdaptiveDesignable {
    var presenter: StakingMainPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconButton: RoundedButton!
    @IBOutlet private var iconButtonWidth: NSLayoutConstraint!
    @IBOutlet private var actionButton: TriangularedButton!
    @IBOutlet weak var amountInputView: AmountInputView!

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

    @IBOutlet weak var estimateWidgetTitleLabel: UILabel!

    @IBOutlet weak var monthlyTitleLabel: UILabel!
    @IBOutlet weak var monthlyAmountLabel: UILabel!
    @IBOutlet weak var monthlyFiatAmountLabel: UILabel!
    @IBOutlet weak var monthlyPercentageLabel: UILabel!

    @IBOutlet weak var yearlyTitleLabel: UILabel!
    @IBOutlet weak var yearlyAmountLabel: UILabel!
    @IBOutlet weak var yearlyFiatAmountLabel: UILabel!
    @IBOutlet weak var yearlyPercentageLabel: UILabel!

    var iconGenerator: IconGenerating?
    var uiFactory: UIFactoryProtocol!

    // MARK: - Private declarations
    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var monthlyRewardViewModel: LocalizableResource<RewardViewModelProtocol>?
    private var yearlyRewardViewModel: LocalizableResource<RewardViewModelProtocol>?

    private var chainName: String = ""

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        setupInitBalanceView()
        setupInitRewardView()
        setupLocalization()
        presenter.setup()
        configureCollectionView()
    }

    @IBAction func actionMain() {
        amountInputView.textField.resignFirstResponder()

        presenter.performMainAction()
    }

    @IBAction func actionIcon() {
        presenter.performAccountAction()
    }

    @IBAction func toggleNetworkWidgetVisibility(sender: ActionTitleControl) {
        amountInputView.textField.resignFirstResponder()
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

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = uiFactory.createAmountAccessoryView(for: self, locale: locale)

        amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupInitBalanceView() {
        amountInputView.priceText = ""
        amountInputView.balanceText = ""

        let textColor = R.color.colorWhite()!
        let placeholder = NSAttributedString(string: "0",
                                             attributes: [
                                                .foregroundColor: textColor.withAlphaComponent(0.5),
                                                .font: UIFont.h4Title
                                             ])

        amountInputView.textField.attributedPlaceholder = placeholder
        amountInputView.textField.keyboardType = .decimalPad

        amountInputView.textField.delegate = self
    }

    private func setupInitRewardView() {
        monthlyAmountLabel.text = ""
        monthlyPercentageLabel.text = ""
        monthlyFiatAmountLabel.text = ""

        yearlyAmountLabel.text = ""
        yearlyPercentageLabel.text = ""
        yearlyFiatAmountLabel.text = ""
    }

    private func applyAsset() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        if let viewModel = assetViewModel?.value(for: locale) {
            amountInputView.balanceText = R.string.localizable
                .commonBalanceFormat(viewModel.balance ?? "",
                                     preferredLanguages: locale.rLanguages)
            amountInputView.priceText = viewModel.price

            amountInputView.assetIcon = viewModel.icon
            amountInputView.symbol = viewModel.symbol
        }
        applyReward()
    }

    private func applyReward() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        if let viewModel = monthlyRewardViewModel?.value(for: locale) {
            monthlyAmountLabel.text = viewModel.amount
            monthlyFiatAmountLabel.text = viewModel.price
            monthlyPercentageLabel.text = viewModel.increase
        }

        if let viewModel = yearlyRewardViewModel?.value(for: locale) {
            yearlyAmountLabel.text = viewModel.amount
            yearlyFiatAmountLabel.text = viewModel.price
            yearlyPercentageLabel.text = viewModel.increase
        }
        applyChainName()
    }

    private func applyChainName() {
        let languages = (localizationManager?.selectedLocale ?? Locale.current).rLanguages

        titleControl.titleLabel.text = R.string.localizable
            .stakingMainNetworkTitle(chainName,
                                     preferredLanguages: languages)
    }
}

extension StakingMainViewController: Localizable {
    private func setupLocalization() {
        let languages = (localizationManager?.selectedLocale ?? Locale.current).rLanguages

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

        estimateWidgetTitleLabel.text = R.string.localizable.stakingEstimateEarningTitle(preferredLanguages: languages)
        monthlyTitleLabel.text = R.string.localizable
            .stakingMonthPeriodTitle(preferredLanguages: languages)
        yearlyTitleLabel.text = R.string.localizable
            .stakingYearPeriodTitle(preferredLanguages: languages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .stakingStartTitle(preferredLanguages: languages)

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)

        applyAsset()
        setupBalanceAccessoryView()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingMainViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        return amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension StakingMainViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountInputView.fieldText = amountInputViewModel?.displayAmount

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingMainViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on view: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on view: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension StakingMainViewController: StakingMainViewProtocol {
    func didReceiveChainName(chainName newChainName: LocalizableResource<String>) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        self.chainName = newChainName.value(for: locale)
        applyChainName()
    }

    func didReceiveRewards(monthlyViewModel: LocalizableResource<RewardViewModelProtocol>,
                           yearlyViewModel: LocalizableResource<RewardViewModelProtocol>) {
        self.monthlyRewardViewModel = monthlyViewModel
        self.yearlyRewardViewModel = yearlyViewModel
        applyReward()
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

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAsset()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let concreteViewModel = viewModel.value(for: locale)

        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = concreteViewModel

        amountInputView.fieldText = concreteViewModel.displayAmount
        concreteViewModel.observable.add(observer: self)
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
