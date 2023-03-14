import UIKit
import CommonWallet
import SoraFoundation
import SoraUI

protocol RewardEstimationViewDelegate: AnyObject {
    func rewardEstimationView(_ view: RewardEstimationView, didChange amount: Decimal?)
    func rewardEstimationView(_ view: RewardEstimationView, didSelect percentage: Float)
    func rewardEstimationDidRequestInfo(_ view: RewardEstimationView)
}

final class RewardEstimationView: LocalizableView {
    @IBOutlet var backgroundView: TriangularedBlurView!
    @IBOutlet var amountInputView: AmountInputView!

    @IBOutlet var estimateWidgetTitleLabel: UILabel!

    @IBOutlet var monthlyTitleLabel: UILabel!
    @IBOutlet var monthlyAmountLabel: UILabel!
    @IBOutlet var monthlyFiatAmountLabel: UILabel!

    @IBOutlet var yearlyTitleLabel: UILabel!
    @IBOutlet var yearlyAmountLabel: UILabel!
    @IBOutlet var yearlyFiatAmountLabel: UILabel!

    @IBOutlet private var infoButton: RoundedButton!

    private var skeletonView: SkrullableView?

    var amountFormatterFactory: AssetBalanceFormatterFactoryProtocol?

    weak var delegate: RewardEstimationViewDelegate?

    var uiFactory: UIFactoryProtocol? {
        didSet {
            setupInputAccessoryView()
        }
    }

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyInputViewModel()

            if widgetViewModel != nil {
                applyWidgetViewModel()
            }
        }
    }

    private var inputViewModel: IAmountInputViewModel?
    private var widgetViewModel: StakingEstimationViewModel?

    override func awakeFromNib() {
        super.awakeFromNib()

        amountInputView.textField.delegate = self

        applyLocalization()

        setupAmountField()
    }

    func bind(viewModel: StakingEstimationViewModel) {
        widgetViewModel?.assetBalance.value(for: locale).iconViewModel?.cancel(
            on: amountInputView.iconView
        )

        widgetViewModel = viewModel

        if inputViewModel == nil || (inputViewModel?.decimalAmount != widgetViewModel?.amount) {
            applyInputViewModel()
        }

        applyWidgetViewModel()
    }

    private func applyWidgetViewModel() {
        if let viewModel = widgetViewModel?.assetBalance.value(for: locale) {
            amountInputView.balanceText = R.string.localizable
                .commonAvailableFormat(
                    viewModel.balance ?? "",
                    preferredLanguages: locale.rLanguages
                )
            amountInputView.priceText = viewModel.price

            amountInputView.assetIcon = nil

            viewModel.iconViewModel?.loadAmountInputIcon(on: amountInputView.iconView, animated: true)

            amountInputView.symbol = viewModel.symbol
        }

        if let viewModel = widgetViewModel?.rewardViewModel?.value(for: locale) {
            stopLoadingIfNeeded()

            infoButton.isHidden = false

            monthlyTitleLabel.text = viewModel.monthlyReward.increase.map {
                R.string.localizable.stakingMonthPeriodFormat($0, preferredLanguages: locale.rLanguages)
            }

            monthlyAmountLabel.text = viewModel.monthlyReward.amount
            monthlyFiatAmountLabel.text = viewModel.monthlyReward.price

            yearlyTitleLabel.text = viewModel.yearlyReward.increase.map {
                R.string.localizable.stakingYearPeriodFormat($0, preferredLanguages: locale.rLanguages)
            }

            yearlyAmountLabel.text = viewModel.yearlyReward.amount
            yearlyFiatAmountLabel.text = viewModel.yearlyReward.price
        } else {
            startLoadingIfNeeded()

            infoButton.isHidden = true
        }
    }

    private func applyInputViewModel() {
        guard let widgetViewModel = widgetViewModel, let amountFormatterFactory = amountFormatterFactory else {
            return
        }

        let assetInfo = widgetViewModel.assetInfo

        let formatter = amountFormatterFactory.createInputFormatter(for: assetInfo).value(for: locale)
        let newInputViewModel = AmountInputViewModel(
            symbol: assetInfo.symbol,
            amount: widgetViewModel.amount,
            formatter: formatter,
            precision: Int16(formatter.maximumFractionDigits)
        )

        inputViewModel?.observable.remove(observer: self)

        inputViewModel = newInputViewModel

        amountInputView.fieldText = newInputViewModel.displayAmount
        newInputViewModel.observable.add(observer: self)
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        estimateWidgetTitleLabel.text = R.string.localizable.stakingEstimateEarningTitle_v190(
            preferredLanguages: languages
        )

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)

        setupInputAccessoryView()
    }

    private func setupInputAccessoryView() {
        guard let accessoryView = uiFactory?.createAmountAccessoryView(for: self, locale: locale) else {
            return
        }

        amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupAmountField() {
        let textColor = R.color.colorWhite()!
        let placeholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: textColor.withAlphaComponent(0.5),
                .font: UIFont.h4Title
            ]
        )

        amountInputView.textField.attributedPlaceholder = placeholder
        amountInputView.textField.keyboardType = .decimalPad
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        monthlyTitleLabel.alpha = 0.0
        monthlyAmountLabel.alpha = 0.0
        monthlyFiatAmountLabel.alpha = 0.0

        yearlyTitleLabel.alpha = 0.0
        yearlyAmountLabel.alpha = 0.0
        yearlyFiatAmountLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        monthlyTitleLabel.alpha = 1.0
        monthlyAmountLabel.alpha = 1.0
        monthlyFiatAmountLabel.alpha = 1.0

        yearlyTitleLabel.alpha = 1.0
        yearlyAmountLabel.alpha = 1.0
        yearlyFiatAmountLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: backgroundView)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)

        return [
            SingleSkeleton.createRow(
                inPlaceOf: monthlyTitleLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: monthlyAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: monthlyFiatAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: yearlyTitleLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: yearlyAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: yearlyFiatAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            )
        ]
    }

    @IBAction private func infoTouchUpInside() {
        delegate?.rewardEstimationDidRequestInfo(self)
    }
}

extension RewardEstimationView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension RewardEstimationView: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        delegate?.rewardEstimationView(self, didSelect: percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension RewardEstimationView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        guard let inputViewModel = inputViewModel else {
            return
        }

        amountInputView.fieldText = inputViewModel.displayAmount

        guard let amount = inputViewModel.decimalAmount else {
            return
        }

        delegate?.rewardEstimationView(self, didChange: amount)
    }
}

extension RewardEstimationView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }
}
