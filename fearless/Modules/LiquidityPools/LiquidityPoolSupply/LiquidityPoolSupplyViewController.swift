import UIKit
import SoraFoundation
import SnapKit

protocol LiquidityPoolSupplyViewOutput: AnyObject {
    func didLoad(view: LiquidityPoolSupplyViewInput)
    func handleViewAppeared()
    func didTapBackButton()
    func didTapApyInfo()
    func didTapPreviewButton()
    func selectFromAmountPercentage(_ percentage: Float)
    func updateFromAmount(_ newValue: Decimal)
    func selectToAmountPercentage(_ percentage: Float)
    func updateToAmount(_ newValue: Decimal)
    func didTapFeeInfo()
}

final class LiquidityPoolSupplyViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = LiquidityPoolSupplyViewLayout
    var keyboardHandler: FearlessKeyboardHandler?

    private enum Constants {
        static let delay: CGFloat = 0.7
    }

    // MARK: Private properties

    private let output: LiquidityPoolSupplyViewOutput

    private var amountFromInputViewModel: IAmountInputViewModel?
    private var amountToInputViewModel: IAmountInputViewModel?

    private var assetFromViewModel: AssetBalanceViewModelProtocol?
    private var assetToViewModel: AssetBalanceViewModelProtocol?

    // MARK: - Constructor

    init(
        output: LiquidityPoolSupplyViewOutput,
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
        view = LiquidityPoolSupplyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        output.didLoad(view: self)
        setupActions()
        addEndEditingTapGesture(for: rootView.contentView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isBeingPresented || isMovingToParent {
            output.handleViewAppeared()
        }

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

        rootView.swapFromInputView.textField.isUserInteractionEnabled = false
        rootView.swapToInputView.textField.isUserInteractionEnabled = false

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createDoneAccessoryView(for: self, locale: locale)
        rootView.swapFromInputView.textField.inputAccessoryView = accessoryView
        updatePreviewButton()
    }

    private func updatePreviewButton() {
        let isEnabled = amountFromInputViewModel?.isValid == true && amountToInputViewModel?.isValid == true && assetToViewModel != nil && assetFromViewModel != nil
        rootView.previewButton.set(enabled: isEnabled)
    }

    private func setupActions() {
        rootView.backButton.addTarget(
            self,
            action: #selector(handleTapBackButton),
            for: .touchUpInside
        )

        rootView.previewButton.addTarget(
            self,
            action: #selector(handleTapPreviewButton),
            for: .touchUpInside
        )

        let tapApyInfo = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapApyInfo)
        )
        rootView.apyView
            .addGestureRecognizer(tapApyInfo)

        let tapFeeInfo = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapFeeInfo)
        )
        rootView.networkFeeView
            .addGestureRecognizer(tapFeeInfo)
    }

    // MARK: - Private actions

    @objc private func handleTapBackButton() {
        output.didTapBackButton()
    }

    @objc private func handleTapApyInfo() {
        output.didTapApyInfo()
    }

    @objc private func handleTapPreviewButton() {
        output.didTapPreviewButton()
    }

    @objc private func handleTapFeeInfo() {
        output.didTapFeeInfo()
    }
}

// MARK: - LiquidityPoolSupplyViewInput

extension LiquidityPoolSupplyViewController: LiquidityPoolSupplyViewInput {
    func didReceiveSwapQuoteReady() {
        print("didReceiveSwapQuoteReady")
        rootView.swapFromInputView.textField.isUserInteractionEnabled = true
        rootView.swapToInputView.textField.isUserInteractionEnabled = true
    }

    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?) {
        assetFromViewModel = viewModel
        rootView.bindSwapFrom(assetViewModel: viewModel)
        updatePreviewButton()
    }

    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?) {
        assetToViewModel = viewModel
        rootView.bindSwapTo(assetViewModel: viewModel)
        updatePreviewButton()
    }

    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?) {
        amountFromInputViewModel = amountInputViewModel
        amountInputViewModel?.observable.remove(observer: self)
        amountInputViewModel?.observable.add(observer: self)
        rootView.swapFromInputView.inputFieldText = amountInputViewModel?.displayAmount
        updatePreviewButton()
    }

    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?) {
        amountToInputViewModel = amountInputViewModel
        amountInputViewModel?.observable.remove(observer: self)
        amountInputViewModel?.observable.add(observer: self)
        rootView.swapToInputView.inputFieldText = amountInputViewModel?.displayAmount
        updatePreviewButton()
    }

    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?) {
        rootView.bind(fee: fee)
        updatePreviewButton()
    }

    func setButtonLoadingState(isLoading: Bool) {
        rootView.previewButton.set(loading: isLoading)
        updatePreviewButton()
    }

    func didUpdating() {
        DispatchQueue.main.async {
            self.rootView.previewButton.set(enabled: false)
        }
    }

    func didReceiveViewModel(_ viewModel: LiquidityPoolSupplyViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension LiquidityPoolSupplyViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - AmountInputAccessoryViewDelegate

extension LiquidityPoolSupplyViewController: AmountInputAccessoryViewDelegate {
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

extension LiquidityPoolSupplyViewController: UITextFieldDelegate {
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
        if textField == rootView.swapToInputView.textField {
            rootView.swapFromInputView.textField.resignFirstResponder()
        }
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.swapFromInputView.set(highlighted: false, animated: false)
        rootView.swapToInputView.set(highlighted: false, animated: false)
    }
}

// MARK: - AmountInputViewModelObserver

extension LiquidityPoolSupplyViewController: AmountInputViewModelObserver {
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
            guard let amountFrom = amountFromInputViewModel?.decimalAmount else {
                output.updateFromAmount(0)

                return
            }
            output.updateFromAmount(amountFrom)
        }

        if rootView.swapToInputView.textField.isFirstResponder {
            guard let amountTo = amountToInputViewModel?.decimalAmount else {
                output.updateToAmount(0)

                return
            }
            output.updateToAmount(amountTo)
        }
    }
}

// MARK: - KeyboardViewAdoptable

extension LiquidityPoolSupplyViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { UIConstants.bigOffset }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
