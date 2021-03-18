import UIKit
import CommonWallet
import SoraFoundation

protocol RewardEstimationViewDelegate: class {
    func rewardEstimationView(_ view: RewardEstimationView, didChange amount: Decimal?)
    func rewardEstimationView(_ view: RewardEstimationView, didSelect percentage: Float)
    func rewardEstimationDidStartAction(_ view: RewardEstimationView)
}

final class RewardEstimationView: LocalizableView {
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

    @IBOutlet private var actionButton: TriangularedButton!

    var amountFormatterFactory: NumberFormatterFactoryProtocol?

    var actionTitle: LocalizableResource<String> = LocalizableResource { locale in
        R.string.localizable.stakingStartTitle(preferredLanguages: locale.rLanguages)
    } {
        didSet {
            applyActionTitle()
        }
    }

    weak var delegate: RewardEstimationViewDelegate?

    var uiFactory: UIFactoryProtocol? {
        didSet {
            setupInputAccessoryView()
        }
    }

    var locale: Locale = Locale.current {
        didSet {
            applyLocalization()
            applyInputViewModel()
            applyWidgetViewModel()
        }
    }

    private var inputViewModel: AmountInputViewModelProtocol?
    private var widgetViewModel: StakingEstimationViewModelProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()

        amountInputView.textField.delegate = self

        applyLocalization()

        setupAmountField()
    }

    func bind(viewModel: StakingEstimationViewModelProtocol) {
        widgetViewModel = viewModel

        if inputViewModel == nil || (inputViewModel?.decimalAmount != widgetViewModel?.amount) {
            applyInputViewModel()
        }

        applyWidgetViewModel()
    }

    private func applyWidgetViewModel() {
        if let viewModel = widgetViewModel?.assetBalance.value(for: locale) {
            amountInputView.balanceText = R.string.localizable
                .commonBalanceFormat(viewModel.balance ?? "",
                                     preferredLanguages: locale.rLanguages)
            amountInputView.priceText = viewModel.price

            amountInputView.assetIcon = viewModel.icon
            amountInputView.symbol = viewModel.symbol
        }

        if let viewModel = widgetViewModel?.monthlyReward.value(for: locale) {
            monthlyAmountLabel.text = viewModel.amount
            monthlyFiatAmountLabel.text = viewModel.price
            monthlyPercentageLabel.text = viewModel.increase
        }

        if let viewModel = widgetViewModel?.yearlyReward.value(for: locale) {
            yearlyAmountLabel.text = viewModel.amount
            yearlyFiatAmountLabel.text = viewModel.price
            yearlyPercentageLabel.text = viewModel.increase
        }
    }

    private func applyInputViewModel() {
        guard let widgetViewModel = widgetViewModel, let amountFormatterFactory = amountFormatterFactory else {
            return
        }

        let asset = widgetViewModel.asset

        let formatter = amountFormatterFactory
            .createInputFormatter(for: widgetViewModel.asset).value(for: locale)
        let newInputViewModel = AmountInputViewModel(symbol: asset.symbol,
                                                     amount: widgetViewModel.amount,
                                                     limit: widgetViewModel.inputLimit,
                                                     formatter: formatter,
                                                     inputLocale: locale,
                                                     precision: Int16(formatter.maximumFractionDigits))

        inputViewModel?.observable.remove(observer: self)

        inputViewModel = newInputViewModel

        amountInputView.fieldText = newInputViewModel.displayAmount
        newInputViewModel.observable.add(observer: self)
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        estimateWidgetTitleLabel.text = R.string.localizable.stakingEstimateEarningTitle(preferredLanguages: languages)
        monthlyTitleLabel.text = R.string.localizable
            .stakingMonthPeriodTitle(preferredLanguages: languages)
        yearlyTitleLabel.text = R.string.localizable
            .stakingYearPeriodTitle(preferredLanguages: languages)

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)

        setupInputAccessoryView()
        applyActionTitle()
    }

    private func applyActionTitle() {
        let title = actionTitle.value(for: locale)
        actionButton.imageWithTitleView?.title = title
        actionButton.invalidateLayout()
    }

    private func setupInputAccessoryView() {
        guard let accessoryView = uiFactory?.createAmountAccessoryView(for: self, locale: locale) else {
            return
        }

        amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupAmountField() {
        let textColor = R.color.colorWhite()!
        let placeholder = NSAttributedString(string: "0",
                                             attributes: [
                                                .foregroundColor: textColor.withAlphaComponent(0.5),
                                                .font: UIFont.h4Title
                                             ])

        amountInputView.textField.attributedPlaceholder = placeholder
        amountInputView.textField.keyboardType = .decimalPad
    }

    @IBAction private func actionTouchUpInside() {
        amountInputView.textField.resignFirstResponder()

        delegate?.rewardEstimationDidStartAction(self)
    }
}

extension RewardEstimationView: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        return inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension RewardEstimationView: AmountInputAccessoryViewDelegate {
    func didSelect(on view: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        delegate?.rewardEstimationView(self, didSelect: percentage)
    }

    func didSelectDone(on view: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension RewardEstimationView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        guard let inputViewModel = inputViewModel else {
            return
        }

        amountInputView.fieldText = inputViewModel.displayAmount

        let amount = inputViewModel.decimalAmount

        delegate?.rewardEstimationView(self, didChange: amount)
    }
}
