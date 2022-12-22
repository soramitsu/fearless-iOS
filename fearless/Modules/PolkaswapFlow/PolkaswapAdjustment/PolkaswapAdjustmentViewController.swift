import UIKit
import SoraFoundation
import CommonWallet
import SnapKit

final class PolkaswapAdjustmentViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = PolkaswapAdjustmentViewLayout
    var keyboardHandler: FearlessKeyboardHandler?

    private enum Constants {
        static let delay: CGFloat = 0.7
    }

    // MARK: Private properties

    private let output: PolkaswapAdjustmentViewOutput

    private var amountFromInputViewModel: AmountInputViewModelProtocol?
    private var amountToInputViewModel: AmountInputViewModelProtocol?

    // MARK: - Constructor

    init(
        output: PolkaswapAdjustmentViewOutput,
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
        view = PolkaswapAdjustmentViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupActions()
        configure()
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
        navigationController?.setNavigationBarHidden(true, animated: true)

        rootView.swapToInputView.textField.delegate = self
        rootView.swapFromInputView.textField.delegate = self

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.swapFromInputView.textField.inputAccessoryView = accessoryView
        rootView.swapToInputView.textField.inputAccessoryView = accessoryView
        updatePreviewButton()
    }

    private func updatePreviewButton() {
        let isEnabled = amountFromInputViewModel?.isValid == true && amountToInputViewModel?.isValid == true
        rootView.previewButton.set(enabled: isEnabled)
    }

    private func setupActions() {
        rootView.backButton.addTarget(
            self,
            action: #selector(handleTapBackButton),
            for: .touchUpInside
        )
        rootView.marketButton.addTarget(
            self,
            action: #selector(handleTapMarketButton),
            for: .touchUpInside
        )
        rootView.swapFromInputView.selectHandler = { [weak self] in
            self?.output.didTapSelectFromAsset()
        }
        rootView.swapToInputView.selectHandler = { [weak self] in
            self?.output.didTapSelectToAsset()
        }
        rootView.switchSwapButton.addTarget(
            self,
            action: #selector(handleTapSwitchInputsButton),
            for: .touchUpInside
        )

        let tapMinReceiveInfo = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapMinReceiveInfo)
        )
        let tapLiquidityProviderFeeInfo = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapLiquidityProviderFeeInfo)
        )
        let tapNetworkFeeInfo = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapNetworkFeeInfo)
        )
        rootView.minReceivedView.titleLabel
            .addGestureRecognizer(tapMinReceiveInfo)
        rootView.liquidityProviderFeeView.titleLabel
            .addGestureRecognizer(tapLiquidityProviderFeeInfo)
        rootView.networkFeeView.titleLabel
            .addGestureRecognizer(tapNetworkFeeInfo)

        rootView.previewButton.addTarget(
            self,
            action: #selector(handleTapPreviewButton),
            for: .touchUpInside
        )
    }

    // MARK: - Private actions

    @objc func handleTapBackButton() {
        output.didTapBackButton()
    }

    @objc func handleTapMarketButton() {
        output.didTapMarketButton()
    }

    @objc func handleTapSwitchInputsButton() {
        output.didTapSwitchInputsButton()
    }

    @objc func handleTapMinReceiveInfo() {
        output.didTapMinReceiveInfo()
    }

    @objc func handleTapLiquidityProviderFeeInfo() {
        output.didTapLiquidityProviderFeeInfo()
    }

    @objc func handleTapNetworkFeeInfo() {
        output.didTapNetworkFeeInfo()
    }

    @objc func handleTapPreviewButton() {
        output.didTapPreviewButton()
    }
}

// MARK: - PolkaswapAdjustmentViewInput

extension PolkaswapAdjustmentViewController: PolkaswapAdjustmentViewInput {
    func didReceive(market: LiquiditySourceType) {
        rootView.marketButton.setTitle(market.name)
    }

    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?) {
        rootView.bindSwapFrom(assetViewModel: viewModel)
    }

    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?) {
        rootView.bindSwapTo(assetViewModel: viewModel)
    }

    func didReceiveSwapFrom(amountInputViewModel: AmountInputViewModelProtocol?) {
        amountFromInputViewModel = amountInputViewModel
        amountInputViewModel?.observable.remove(observer: self)
        amountInputViewModel?.observable.add(observer: self)
        rootView.swapFromInputView.inputFieldText = amountInputViewModel?.displayAmount
        updatePreviewButton()
    }

    func didReceiveSwapTo(amountInputViewModel: AmountInputViewModelProtocol?) {
        amountToInputViewModel = amountInputViewModel
        amountInputViewModel?.observable.remove(observer: self)
        amountInputViewModel?.observable.add(observer: self)
        rootView.swapToInputView.inputFieldText = amountInputViewModel?.displayAmount
        updatePreviewButton()
    }

    func didReceive(receiveValue: BalanceViewModelProtocol?) {
        rootView.minReceivedView.bindBalance(viewModel: receiveValue)
        rootView.minReceivedView.isHidden = false
        updatePreviewButton()
    }

    func didReceiveLuquidityProvider(fee: BalanceViewModelProtocol?) {
        rootView.liquidityProviderFeeView.bindBalance(viewModel: fee)
        rootView.liquidityProviderFeeView.isHidden = false
        updatePreviewButton()
    }

    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bindBalance(viewModel: fee)
        rootView.networkFeeView.isHidden = false
        updatePreviewButton()
    }

    func didUpdating() {
        DispatchQueue.main.async {
            self.rootView.previewButton.set(enabled: false)
        }
    }

    func didReceive(variant: SwapVariant) {
        rootView.bind(swapVariant: variant)
    }
}

// MARK: - Localizable

extension PolkaswapAdjustmentViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - AmountInputAccessoryViewDelegate

extension PolkaswapAdjustmentViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        if rootView.swapFromInputView.textField.isFirstResponder {
            output.selectFromAmountPercentage(percentage)
        } else if rootView.swapToInputView.textField.isFirstResponder {
            output.selectToAmountPercentage(percentage)
        }
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        if rootView.swapFromInputView.textField.isFirstResponder {
            rootView.swapFromInputView.textField.resignFirstResponder()
        } else if rootView.swapToInputView.textField.isFirstResponder {
            rootView.swapToInputView.textField.resignFirstResponder()
        }
    }
}

// MARK: - UITextFieldDelegate

extension PolkaswapAdjustmentViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField == rootView.swapFromInputView.textField {
            return amountFromInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        } else if textField == rootView.swapToInputView.textField {
            return amountToInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let swapFromIsFirstResponder = textField == rootView.swapFromInputView.textField
        rootView.swapFromInputView.set(highlighted: swapFromIsFirstResponder, animated: false)

        if textField == rootView.swapToInputView.textField, amountToInputViewModel != nil {
            let swapToIsFirstResponder = textField == rootView.swapToInputView.textField
            rootView.swapToInputView.set(highlighted: swapToIsFirstResponder, animated: false)
        } else if textField == rootView.swapToInputView.textField {
            rootView.swapToInputView.textField.resignFirstResponder()
            output.didTapSelectToAsset()
        }
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.swapFromInputView.set(highlighted: false, animated: false)
        rootView.swapToInputView.set(highlighted: false, animated: false)
    }
}

// MARK: - AmountInputViewModelObserver

extension PolkaswapAdjustmentViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.swapFromInputView.inputFieldText = amountFromInputViewModel?.displayAmount
        rootView.swapToInputView.inputFieldText = amountToInputViewModel?.displayAmount

        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(updateAmounts),
            object: nil
        )
        perform(#selector(updateAmounts), with: nil, afterDelay: Constants.delay)
    }

    @objc private func updateAmounts() {
        if rootView.swapFromInputView.textField.isFirstResponder {
            let amountFrom = amountFromInputViewModel?.decimalAmount ?? .zero
            output.updateFromAmount(amountFrom)
        }

        if rootView.swapToInputView.textField.isFirstResponder {
            let amountTo = amountToInputViewModel?.decimalAmount ?? .zero
            output.updateToAmount(amountTo)
        }
    }
}

// MARK: - KeyboardViewAdoptable

extension PolkaswapAdjustmentViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { UIConstants.bigOffset }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}