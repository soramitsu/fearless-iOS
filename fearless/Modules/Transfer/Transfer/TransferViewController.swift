import UIKit
import SoraUI
import SoraFoundation
import SnapKit

protocol TransferViewOutput: AnyObject {
    func didLoad(view: TransferViewInput)
    func didTapBackButton()
    func didTapContinueButton()
    func didTapScanButton()
    func didTapHistoryButton()
    func didTapPasteButton()
    func didTapSelectAsset()
    func searchTextDidChanged(_ text: String)
    func selectAmountPercentage(_ percentage: Float, validate: Bool)
    func updateAmount(_ newValue: Decimal)
    func didSwitchSendAll(_ enabled: Bool)
    func updateComment(_ text: String?)
}

final class TransferViewController: UIViewController, ViewHolder {
    typealias RootViewType = SendViewLayout

    // MARK: Private properties

    private let output: TransferViewOutput
    private let initialData: SendFlowInitialData

    private var amountInputViewModel: IAmountInputViewModel?
    private var commentInputViewModel: InputViewModelProtocol?

    // MARK: - Constructor

    init(
        initialData: SendFlowInitialData,
        output: TransferViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.initialData = initialData
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
        view = SendViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupLocalization()
        configure()
        addEndEditingTapGesture(for: rootView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - Private methods

    private func setupLocalization() {
        rootView.locale = selectedLocale
    }

    private func configure() {
        rootView.searchView.textField.delegate = self
        rootView.amountView.textField.delegate = self
        rootView.commentTextField.animatedInputField.delegate = self
        rootView.commentTextField.animatedInputField.addTarget(
            self,
            action: #selector(actionInputChange),
            for: .editingChanged
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(continueButtonClicked),
            for: .touchUpInside
        )
        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )
        rootView.scanButton.addTarget(
            self,
            action: #selector(scanButtonClicked),
            for: .touchUpInside
        )
        rootView.historyButton.addTarget(
            self,
            action: #selector(historyButtonClicked),
            for: .touchUpInside
        )
        rootView.searchView.onPasteTapped = { [weak self] in
            self?.output.didTapPasteButton()
        }

        rootView.amountView.selectHandler = { [weak self] in
            self?.output.didTapSelectAsset()
        }

        rootView.sendAllSwitch.addTarget(self, action: #selector(sendAllToggleSwitched), for: .valueChanged)
    }

    @objc private func continueButtonClicked() {
        output.didTapContinueButton()
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func scanButtonClicked() {
        output.didTapScanButton()
    }

    @objc private func historyButtonClicked() {
        output.didTapHistoryButton()
    }

    @objc private func sendAllToggleSwitched() {
        output.didSwitchSendAll(rootView.sendAllSwitch.isOn)
    }

    @objc private func actionInputChange() {
        if commentInputViewModel?.inputHandler.value != rootView.commentTextField.text {
            rootView.commentTextField.text = commentInputViewModel?.inputHandler.value
        }
    }
}

extension TransferViewController: TransferViewInput {
    func setCommentInput(isVisible: Bool) {
        rootView.commentTextField.isHidden = !isVisible
    }

    func didReceiveContinueButton(isReady: Bool) {
        rootView.actionButton.set(enabled: isReady)
    }

    func setInputAccessoryView(visible: Bool) {
        rootView.amountView.textField.resignFirstResponder()
        if visible {
            let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: selectedLocale)
            rootView.amountView.textField.inputAccessoryView = accessoryView
        } else {
            rootView.amountView.textField.inputAccessoryView = nil
        }
    }

    func didBlockUserInteractive(isUserInteractiveAmount: Bool) {
        rootView.searchView.isUserInteractionEnabled = isUserInteractiveAmount
        rootView.selectNetworkView.isUserInteractionEnabled = isUserInteractiveAmount
        rootView.amountView.textField.isUserInteractionEnabled = isUserInteractiveAmount
        rootView.optionsStackView.isHidden = !isUserInteractiveAmount
        if isUserInteractiveAmount {
            rootView.amountView.selectHandler = { [weak self] in
                self?.output.didTapSelectAsset()
            }
        } else {
            rootView.amountView.selectHandler = nil
        }
    }

    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?) {
        if let assetViewModel = assetBalanceViewModel {
            rootView.bind(assetViewModel: assetViewModel)
        }
    }

    func didReceive(amountInputViewModel: IAmountInputViewModel?) {
        self.amountInputViewModel = amountInputViewModel
        if let amountViewModel = amountInputViewModel {
            amountViewModel.observable.remove(observer: self)
            amountViewModel.observable.add(observer: self)
            rootView.amountView.inputFieldText = amountViewModel.displayAmount
        }
    }

    func setCommentViewModel(_ viewModel: InputViewModelProtocol?) {
        commentInputViewModel = viewModel
        rootView.commentTextField.animatedInputField.text = viewModel?.inputHandler.value
    }

    func didReceive(selectNetworkViewModel: SelectNetworkViewModel) {
        rootView.bind(selectNetworkviewModel: selectNetworkViewModel)
    }

    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }

    func didReceive(tipViewModel: TipViewModel?) {
        rootView.bind(tipViewModel: tipViewModel)
    }

    func didReceive(scamInfo: ScamInfo?) {
        rootView.bind(scamInfo: scamInfo)
    }

    func didStartFeeCalculation() {
        rootView.actionButton.set(loading: true)
    }

    func didReceive(recipientViewModel viewModel: RecipientViewModel?) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(accountScoreViewModel: AccountScoreViewModel?) {
        rootView.accountScoreView.bind(viewModel: accountScoreViewModel)
    }

    func didStartLoading() {
        rootView.actionButton.set(loading: true)
    }

    func didStopLoading() {
        rootView.actionButton.set(loading: false)
    }

    func setHistoryButton(isVisible: Bool) {
        rootView.historyButton.isHidden = !isVisible
    }

    func switchEnableSendAllState(enabled: Bool) {
        rootView.sendAllSwitch.isOn = enabled
    }

    func switchEnableSendAllVisibility(isVisible: Bool) {
        rootView.switchEnableSendAllVisibility(isVisible: isVisible)
    }
}

extension TransferViewController: HiddableBarWhenPushed {}

extension TransferViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField == rootView.amountView.textField {
            return amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        } else if textField == rootView.searchView.textField {
            if range.length == 1, string.isEmpty {
                output.searchTextDidChanged("")
                textField.text = ""
                return true
            } else if range.length == 0, range.location == 0, string.count > 1 {
                output.searchTextDidChanged(string)
            } else {
                return false
            }
        }
        return false
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField == rootView.searchView.textField {
            output.searchTextDidChanged("")
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else {
            return false
        }
        if textField == rootView.searchView.textField {
            output.searchTextDidChanged(text)
        }
        return false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let amountIsFirstResponder = textField == rootView.amountView.textField
        rootView.amountView.set(highlighted: amountIsFirstResponder, animated: false)
        let searchIsFirstResponder = textField == rootView.searchView.textField
        rootView.searchView.set(highlighted: searchIsFirstResponder, animated: false)
        if searchIsFirstResponder {
            textField.resignFirstResponder()
        }
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.amountView.set(highlighted: false, animated: false)
        rootView.searchView.set(highlighted: false, animated: false)
    }
}

extension TransferViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountView.textField.resignFirstResponder()

        output.selectAmountPercentage(percentage, validate: true)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
    }
}

extension TransferViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount

        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(updateAmount),
            object: nil
        )
        perform(#selector(updateAmount), with: nil, afterDelay: 0.75)
    }

    @objc private func updateAmount() {
        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        output.updateAmount(amount)
    }
}

// MARK: - Localizable

extension TransferViewController: Localizable {
    func applyLocalization() {}
}

extension TransferViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - AnimatedTextFieldDelegate

extension TransferViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: SoraUI.AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        rootView.commentTextField.backgroundView.set(highlighted: false, animated: true)
        return false
    }

    func animatedTextField(
        _ textField: SoraUI.AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let currentViewModel = commentInputViewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(updateAmount),
            object: nil
        )
        perform(#selector(updateComment), with: nil, afterDelay: 0.45)

        return shouldApply
    }

    @objc private func updateComment() {
        let comment = commentInputViewModel?.inputHandler.normalizedValue
        output.updateComment(comment)
    }
}
