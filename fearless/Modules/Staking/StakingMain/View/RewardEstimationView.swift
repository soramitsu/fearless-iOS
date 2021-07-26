import UIKit
import CommonWallet
import SoraFoundation
import SoraUI

protocol RewardEstimationViewDelegate: AnyObject {
    func rewardEstimationView(_ view: RewardEstimationView, didChange amount: Decimal?)
    func rewardEstimationView(_ view: RewardEstimationView, didSelect percentage: Float)
    func rewardEstimationDidStartAction(_ view: RewardEstimationView)
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

    @IBOutlet private var actionButton: TriangularedButton!

    private var skeletonView: SkrullableView?

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

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyInputViewModel()

            if widgetViewModel != nil {
                applyWidgetViewModel()
            }
        }
    }

    private var inputViewModel: AmountInputViewModelProtocol?
    private var widgetViewModel: StakingEstimationViewModel?

    override func awakeFromNib() {
        super.awakeFromNib()

        amountInputView.textField.delegate = self

        applyLocalization()

        setupAmountField()
    }

    func bind(viewModel: StakingEstimationViewModel) {
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

            amountInputView.assetIcon = viewModel.icon
            amountInputView.symbol = viewModel.symbol
        }

        if let viewModel = widgetViewModel?.rewardViewModel?.value(for: locale) {
            stopLoadingIfNeeded()

            infoButton.isHidden = false

            monthlyTitleLabel.text = viewModel.monthlyReward.increase.map {
                R.string.localizable.stakingMonthPeriodFormat_v190($0, preferredLanguages: locale.rLanguages)
            }

            monthlyAmountLabel.text = viewModel.monthlyReward.amount
            monthlyFiatAmountLabel.text = viewModel.monthlyReward.price

            yearlyTitleLabel.text = viewModel.yearlyReward.increase.map {
                R.string.localizable.stakingYearPeriodFormat_v190($0, preferredLanguages: locale.rLanguages)
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

        let asset = widgetViewModel.asset

        let formatter = amountFormatterFactory
            .createInputFormatter(for: widgetViewModel.asset).value(for: locale)
        let newInputViewModel = AmountInputViewModel(
            symbol: asset.symbol,
            amount: widgetViewModel.amount,
            limit: widgetViewModel.inputLimit,
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

        estimateWidgetTitleLabel.text = R.string.localizable.stakingEstimateEarningTitle_v190(preferredLanguages: languages)

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
            createSkeletoRow(
                inPlaceOf: monthlyTitleLabel,
                in: spaceSize,
                size: smallRowSize
            ),

            createSkeletoRow(
                inPlaceOf: monthlyAmountLabel,
                in: spaceSize,
                size: bigRowSize
            ),

            createSkeletoRow(
                inPlaceOf: monthlyFiatAmountLabel,
                in: spaceSize,
                size: smallRowSize
            ),

            createSkeletoRow(
                inPlaceOf: yearlyTitleLabel,
                in: spaceSize,
                size: smallRowSize
            ),

            createSkeletoRow(
                inPlaceOf: yearlyAmountLabel,
                in: spaceSize,
                size: bigRowSize
            ),

            createSkeletoRow(
                inPlaceOf: yearlyFiatAmountLabel,
                in: spaceSize,
                size: smallRowSize
            )
        ]
    }

    private func createSkeletoRow(
        inPlaceOf targetView: UIView,
        in spaceSize: CGSize,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: self)

        let position = CGPoint(
            x: targetFrame.minX + size.width / 2.0,
            y: targetFrame.midY
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }

    @IBAction private func actionTouchUpInside() {
        amountInputView.textField.resignFirstResponder()

        delegate?.rewardEstimationDidStartAction(self)
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

        let amount = inputViewModel.decimalAmount

        delegate?.rewardEstimationView(self, didChange: amount)
    }
}

extension RewardEstimationView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
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
