import UIKit
import SoraFoundation
import SnapKit

final class SendViewController: UIViewController, ViewHolder, SolanaSendFormViewState {
    typealias RootViewType = SendViewLayout

    private let output: SendViewOutput
    private let initialData: SendFlowInitialData
    private lazy var formLifecycle = SolanaSendFormLifecycle(
        controller: self, scope: output as? SolanaSendFormScopeManaging
    )

    var allowsSendFormContinuation: Bool { formLifecycle.isAvailable }

    private var amountInputViewModel: IAmountInputViewModel?
    private var pendingAmountUpdate: (() -> Void)?

    // MARK: - Constructor

    init(
        initialData: SendFlowInitialData,
        output: SendViewOutput,
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
        _ = formLifecycle
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        formLifecycle.resumeIfAvailable()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelPendingAmountUpdate()
        formLifecycle.willDisappear()
    }

    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        formLifecycle.willPresent(controller)
        super.present(controller, animated: animated, completion: completion)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale
    }

    private func configure() {
        let presentingTabBar = tabBarController as? MainTabBarViewController
            ?? presentingViewController as? MainTabBarViewController
            ?? presentingViewController?.tabBarController as? MainTabBarViewController
            ?? navigationController?.presentingViewController?.tabBarController as? MainTabBarViewController
            ?? navigationController?.presentingViewController as? MainTabBarViewController
        rootView.crossNetworkButton.isHidden = presentingTabBar == nil
        rootView.crossNetworkButton.addAction(UIAction { [weak self, weak presentingTabBar] _ in
            guard let self, let presentingTabBar else { return }
            (self.output as? SolanaSendFormScopeManaging)?.suspendSendForm()
            self.view.endEditing(true)
            if self.navigationController?.presentingViewController != nil {
                self.dismiss(animated: true) { presentingTabBar.select(destination: .crossChain) }
            } else {
                presentingTabBar.select(destination: .crossChain)
            }
        }, for: .touchUpInside)
        rootView.searchView.textField.delegate = self
        rootView.amountView.textField.delegate = self

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

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(selectNetworkClicked))
        rootView.selectNetworkView.addGestureRecognizer(tapGesture)

        rootView.amountView.selectHandler = { [weak self] in
            self?.output.didTapSelectAsset()
        }

        rootView.sendAllSwitch.addTarget(self, action: #selector(sendAllToggleSwitched), for: .valueChanged)
    }

    private func updateActionButton() {
        let isEnabled = amountInputViewModel?.isValid == true && rootView.searchView.textField.text?.isNotEmpty == true
        rootView.actionButton.set(enabled: isEnabled)
    }

    @objc private func continueButtonClicked() {
        guard amountInputViewModel?.isValid == true, (amountInputViewModel?.decimalAmount ?? 0) > 0 else { return }
        output.didTapContinueButton()
    }

    @objc private func backButtonClicked() {
        cancelPendingAmountUpdate()
        output.didTapBackButton()
    }

    @objc private func scanButtonClicked() {
        output.didTapScanButton()
    }

    @objc private func historyButtonClicked() {
        output.didTapHistoryButton()
    }

    @objc private func selectNetworkClicked() {
        output.didTapSelectNetwork()
    }

    @objc private func sendAllToggleSwitched() {
        output.didSwitchSendAll(rootView.sendAllSwitch.isOn)
    }
}

// MARK: - SendViewInput

extension SendViewController: SendViewInput {
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
        rootView.searchView.isUserInteractionEnabled = false
        rootView.selectNetworkView.isUserInteractionEnabled = false
        rootView.amountView.selectHandler = nil
        rootView.amountView.textField.isUserInteractionEnabled = isUserInteractiveAmount
        rootView.optionsStackView.isHidden = true
        if isUserInteractiveAmount {
            rootView.amountView.textField.becomeFirstResponder()
        }
    }

    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?) {
        if let assetViewModel = assetBalanceViewModel {
            rootView.bind(assetViewModel: assetViewModel)
        }
    }

    func didReceive(amountInputViewModel: IAmountInputViewModel?) {
        cancelPendingAmountUpdate()
        self.amountInputViewModel?.observable.remove(observer: self)
        self.amountInputViewModel = amountInputViewModel
        if let amountViewModel = amountInputViewModel {
            amountViewModel.observable.add(observer: self)
            rootView.amountView.inputFieldText = amountViewModel.displayAmount
        }
        updateActionButton()
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

    func didStopFeeCalculation() {
        rootView.actionButton.set(loading: false)
        updateActionButton()
    }

    func didStopTipCalculation() {
        updateActionButton()
    }

    func didReceive(viewModel: RecipientViewModel) {
        rootView.bind(viewModel: viewModel)
        updateActionButton()
    }

    func didReceive(accountScoreViewModel: AccountScoreViewModel?) {
        rootView.bind(accountScoreViewModel: accountScoreViewModel)
        updateActionButton()
    }

    func didStartLoading() {
        rootView.actionButton.set(loading: true)
    }

    func didStopLoading() {
        rootView.actionButton.set(loading: false)
        updateActionButton()
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

extension SendViewController: HiddableBarWhenPushed {}

extension SendViewController: UITextFieldDelegate {
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
            rootView.actionButton.set(enabled: false)
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

extension SendViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountView.textField.resignFirstResponder()

        output.selectAmountPercentage(percentage, validate: true)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
    }
}

extension SendViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount
        cancelPendingAmountUpdate()
        pendingAmountUpdate = output.didEditAmount(amountInputViewModel?.decimalAmount ?? 0)
        updateActionButton()
        perform(#selector(updateAmount), with: nil, afterDelay: 0.75)
    }

    private func cancelPendingAmountUpdate() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateAmount), object: nil)
        pendingAmountUpdate = nil
    }

    @objc private func updateAmount() {
        let update = pendingAmountUpdate
        pendingAmountUpdate = nil
        guard allowsSendFormContinuation else { return }
        update?()
    }
}

extension SendViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded, FWAppearance.sendPresentationRestyled else { return }
        setupLocalization()
    }
}

extension SendViewController: KeyboardViewAdoptable {
    var target: Constraint? {
        rootView.keyboardAdoptableConstraint
    }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        guard FWAppearance.sendPresentationRestyled else { return }
        let localFrame = view.convert(frame, from: nil)
        let overlap = frame.isEmpty ? 0 : max(0, view.bounds.maxY - localFrame.minY - view.safeAreaInsets.bottom)
        rootView.keyboardAdoptableConstraint?.update(inset: overlap)
        view.layoutIfNeeded()
        if !frame.isEmpty, rootView.amountView.textField.isFirstResponder {
            let scroll = rootView.contentView.scrollView
            scroll.scrollRectToVisible(
                rootView.amountView.textField.convert(rootView.amountView.textField.bounds, to: scroll), animated: false
            )
        }
    }

    func keyboardWillChangeFrame(notification: Notification) {
        guard FWAppearance.sendPresentationRestyled,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        updateWhileKeyboardFrameChanging(frame.cgRectValue)
    }
}
