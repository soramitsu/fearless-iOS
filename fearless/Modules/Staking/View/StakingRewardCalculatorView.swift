import UIKit
import SoraUI
import CommonWallet

protocol RewardCalculatorViewDelegate: AnyObject {
    func rewardCalculatorView(_ view: StakingRewardCalculatorView, didChange amount: Decimal?)
    func rewardCalculatorView(_ view: StakingRewardCalculatorView, didSelect percentage: Float)
    func rewardCalculatorDidRequestInfo(_ view: StakingRewardCalculatorView)
}

class StakingRewardCalculatorView: UIView {
    private var backgroundView = TriangularedBlurView()
    private var amountInputView = AmountInputViewV2()
    private var monthlyStackView = UIFactory.default.createVerticalStackView()
    private var yearlyStackView = UIFactory.default.createVerticalStackView()
    private var infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfoFilled(), for: .normal)
        return button
    }()

    private var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = .white
        return label
    }()

    private var monthlyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGreen()
        return label
    }()

    private var monthlyAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = .white
        return label
    }()

    private var monthlyFiatAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite16()
        return label
    }()

    private var yearlyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGreen()
        return label
    }()

    private var yearlyAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = .white
        return label
    }()

    private var yearlyFiatAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite16()
        return label
    }()

    private var inputViewModel: AmountInputViewModelProtocol?
    private var widgetViewModel: StakingEstimationViewModel?
    private var skeletonView: SkrullableView?

    var amountFormatterFactory: AssetBalanceFormatterFactoryProtocol?

    weak var delegate: RewardCalculatorViewDelegate?

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

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocalization()

        amountInputView.textField.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: StakingEstimationViewModel) {
        amountFormatterFactory = AssetBalanceFormatterFactory()

        widgetViewModel?.assetBalance.value(for: locale).iconViewModel?.cancel(
            on: amountInputView.iconView
        )

        widgetViewModel = viewModel

        if inputViewModel == nil || (inputViewModel?.decimalAmount != widgetViewModel?.amount) {
            applyInputViewModel()
        }

        applyWidgetViewModel()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(titleLabel)
        addSubview(infoButton)
        addSubview(monthlyStackView)
        addSubview(yearlyStackView)
        addSubview(amountInputView)

        monthlyStackView.addArrangedSubview(monthlyTitleLabel)
        monthlyStackView.addArrangedSubview(monthlyAmountLabel)
        monthlyStackView.addArrangedSubview(monthlyFiatAmountLabel)

        yearlyStackView.addArrangedSubview(yearlyTitleLabel)
        yearlyStackView.addArrangedSubview(yearlyAmountLabel)
        yearlyStackView.addArrangedSubview(yearlyFiatAmountLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.bigOffset)
        }

        infoButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel.snp.centerY)
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.size.equalTo(UIConstants.standardButtonSize)
        }

        monthlyStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.top.equalTo(infoButton.snp.bottom).offset(UIConstants.bigOffset)
        }

        yearlyStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalTo(monthlyStackView.snp.trailing).offset(UIConstants.bigOffset)
            make.width.equalTo(monthlyStackView.snp.width)
            make.top.equalTo(infoButton.snp.bottom).offset(UIConstants.bigOffset)
        }

        amountInputView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.amountViewHeight)
            make.top.equalTo(yearlyStackView.snp.bottom).offset(UIConstants.hugeOffset)
            make.top.equalTo(monthlyStackView.snp.bottom).offset(UIConstants.hugeOffset)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        infoButton.addTarget(self, action: #selector(infoTouchUpInside), for: .touchUpInside)
    }

    private func applyWidgetViewModel() {
        if let viewModel = widgetViewModel?.assetBalance.value(for: locale) {
            amountInputView.bind(viewModel: viewModel)
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
            limit: widgetViewModel.inputLimit,
            formatter: formatter,
            precision: Int16(formatter.maximumFractionDigits)
        )

        inputViewModel?.observable.remove(observer: self)

        inputViewModel = newInputViewModel

        amountInputView.inputFieldText = newInputViewModel.displayAmount

        newInputViewModel.observable.add(observer: self)
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        amountInputView.locale = locale
        titleLabel.text = R.string.localizable.stakingEstimateEarningTitle_v190(
            preferredLanguages: languages
        )

        setupInputAccessoryView()
    }

    private func setupInputAccessoryView() {
        guard let accessoryView = uiFactory?.createAmountAccessoryView(for: self, locale: locale) else {
            return
        }

        amountInputView.textField.inputAccessoryView = accessoryView
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

    @objc private func infoTouchUpInside() {
        delegate?.rewardCalculatorDidRequestInfo(self)
    }
}

extension StakingRewardCalculatorView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension StakingRewardCalculatorView: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        delegate?.rewardCalculatorView(self, didSelect: percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension StakingRewardCalculatorView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        guard let inputViewModel = inputViewModel else {
            return
        }

        amountInputView.inputFieldText = inputViewModel.displayAmount

        let amount = inputViewModel.decimalAmount

        delegate?.rewardCalculatorView(self, didChange: amount)
    }
}

extension StakingRewardCalculatorView: SkeletonLoadable {
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
