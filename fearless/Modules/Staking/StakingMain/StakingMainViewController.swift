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

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        setupInitBalanceView()
        setupInitRewardView()
        setupLocalization()
        presenter.setup()
    }

    @IBAction func actionMain() {
        presenter.performMainAction()
    }

    @IBAction func actionIcon() {
        presenter.performAccountAction()
    }

    // MARK: - Private functions
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
    }
}

extension StakingMainViewController: Localizable {
    private func setupLocalization() {
        let languages = (localizationManager?.selectedLocale ?? Locale.current).rLanguages

        titleLabel.text = R.string.localizable
            .tabbarStakingTitle(preferredLanguages: languages)

        estimateWidgetTitleLabel.text = R.string.localizable.stakingEstimateEarningTitle(preferredLanguages: languages)
        monthlyTitleLabel.text = R.string.localizable.stakingMonthPeriodTitle(preferredLanguages: languages)
        yearlyTitleLabel.text = R.string.localizable.stakingYearPeriodTitle(preferredLanguages: languages)

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
