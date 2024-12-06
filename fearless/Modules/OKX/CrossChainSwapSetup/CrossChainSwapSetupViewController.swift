import UIKit
import SoraFoundation
import SnapKit

protocol CrossChainSwapSetupViewOutput: AnyObject {
    func didLoad(view: CrossChainSwapSetupViewInput)
    func didTapSelectFromAsset()
    func didTapSelectToAsset()
    func didTapBackButton()
    func didTapContinueButton()
    func selectFromAmountPercentage(_ percentage: Float)
    func updateFromAmount(_ newValue: Decimal)
    func didTapSwitchInputsButton()
    func didTapLiquiditySources()
    func didTapSelectRoute()
    func handleDismissingSwipe()
}

final class CrossChainSwapSetupViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = CrossChainSwapSetupViewLayout

    private enum Constants {
        static let amountInputDidChangeDelay: CGFloat = 0.5
    }

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: CrossChainSwapSetupViewOutput

    private var amountFromInputViewModel: IAmountInputViewModel?
    private var amountToInputViewModel: IAmountInputViewModel?

    // MARK: - Constructor

    init(
        output: CrossChainSwapSetupViewOutput,
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
        view = CrossChainSwapSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.interactivePopGestureRecognizer?.delegate = self

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        transitionCoordinator?.animate(alongsideTransition: { context in
            if context.isInteractive {
                print("123123 Interactive swipe transition. Start.")
            } else {
                print("123123 Back button transition. Start.")
            }
        }, completion: { [weak self] context in
            if context.isCancelled {
                print("123123 Interactive swipe transition. Finish. Cancelled. We are still on child screen.")
            } else if context.initiallyInteractive {
                self?.output.handleDismissingSwipe()
                print("123123 Interactive swipe transition. Finish. Sucess. We are on parent screen.")
            } else {
                print("123123 Back button transition. Finish. Sucess. We are on parent screen.")
            }
        })

        transitionCoordinator?.notifyWhenInteractionChanges { _ in
            print("123123 Interactive swipe transition. Finger lifted up or moved back to edge.")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.amountView.selectHandler = { [weak self] in
            self?.output.didTapSelectFromAsset()
        }
        rootView.receiveView.selectHandler = { [weak self] in
            self?.output.didTapSelectToAsset()
        }
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }
        rootView.actionButton.addAction { [weak self] in
            self?.output.didTapContinueButton()
        }
        rootView.liquidityView.selectHandler = { [weak self] in
            self?.output.didTapLiquiditySources()
        }
        rootView.routeView.selectHandler = { [weak self] in
            self?.output.didTapSelectRoute()
        }
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory
            .default
            .createAmountAccessoryView(for: self, locale: locale)
        rootView.amountView.textField.inputAccessoryView = accessoryView
        rootView.amountView.textField.delegate = self
        updatePreviewButton()
    }

    private func updatePreviewButton() {
        let isEnabled = amountFromInputViewModel?.isValid == true && amountToInputViewModel?.isValid == true
        rootView.actionButton.set(enabled: isEnabled, changeStyle: true)
    }
}

// MARK: - CrossChainViewInput

extension CrossChainSwapSetupViewController: CrossChainSwapSetupViewInput {
    func setButtonLoadingState(isLoading: Bool) {
        rootView.actionButton.set(loading: isLoading)
        updatePreviewButton()
    }

    func didReceive(originFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        rootView.bind(originFeeViewModel: originFeeViewModel?.value(for: selectedLocale))
    }

    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?) {
        if let assetViewModel = assetBalanceViewModel {
            rootView.bind(assetViewModel: assetViewModel)
        }
        updatePreviewButton()
    }

    func didReceive(destinationAssetBalanceViewModel: AssetBalanceViewModelProtocol?) {
        if let destinationAssetBalanceViewModel = destinationAssetBalanceViewModel {
            rootView.bind(receiveAssetViewModel: destinationAssetBalanceViewModel)
        }
        updatePreviewButton()
    }

    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?) {
        amountFromInputViewModel = amountInputViewModel
        amountInputViewModel?.observable.remove(observer: self)
        amountInputViewModel?.observable.add(observer: self)
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount
        updatePreviewButton()
    }

    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?) {
        amountToInputViewModel = amountInputViewModel
        amountInputViewModel?.observable.remove(observer: self)
        amountInputViewModel?.observable.add(observer: self)
        rootView.receiveView.inputFieldText = amountInputViewModel?.displayAmount
        updatePreviewButton()
    }

    func didReceiveViewModel(viewModel: CrossChainSwapViewModel?) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension CrossChainSwapSetupViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - KeyboardViewAdoptable

extension CrossChainSwapSetupViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { UIConstants.bigOffset }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - AmountInputViewModelObserver

extension CrossChainSwapSetupViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountFromInputViewModel?.displayAmount
        rootView.receiveView.inputFieldText = amountToInputViewModel?.displayAmount

        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(updateAmounts),
            object: nil
        )
        perform(#selector(updateAmounts), with: nil, afterDelay: 0.7)
    }

    @objc private func updateAmounts() {
        if rootView.amountView.textField.isFirstResponder {
            guard let amountFrom = amountFromInputViewModel?.decimalAmount else {
                output.updateFromAmount(0)

                return
            }
            output.updateFromAmount(amountFrom)
        }
    }
}

// MARK: - AmountInputAccessoryViewDelegate

extension CrossChainSwapSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        if rootView.amountView.textField.isFirstResponder {
            output.selectFromAmountPercentage(percentage)
        }
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        if rootView.amountView.textField.isFirstResponder {
            rootView.amountView.textField.resignFirstResponder()
        }
    }
}

// MARK: - UITextFieldDelegate

extension CrossChainSwapSetupViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField == rootView.amountView.textField {
            return amountFromInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let swapFromIsFirstResponder = textField == rootView.amountView.textField
        rootView.amountView.set(highlighted: swapFromIsFirstResponder, animated: false)

        if textField == rootView.receiveView.textField, amountToInputViewModel != nil {
            let swapToIsFirstResponder = textField == rootView.receiveView.textField
            rootView.receiveView.set(highlighted: swapToIsFirstResponder, animated: false)
        }
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.amountView.set(highlighted: false, animated: false)
        rootView.receiveView.set(highlighted: false, animated: false)
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else {
            return false
        }

        return false
    }
}

extension CrossChainSwapSetupViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer.isEqual(navigationController?.interactivePopGestureRecognizer) else { return true }

        output.handleDismissingSwipe()
        return true
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        print("Gesture event: ", event)
        return true
    }
}
