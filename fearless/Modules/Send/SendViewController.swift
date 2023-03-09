import UIKit
import SoraFoundation
import CommonWallet
import SnapKit

final class SendViewController: UIViewController, ViewHolder {
    typealias RootViewType = SendViewLayout

    // MARK: Private properties

    private let output: SendViewOutput

    private var amountInputViewModel: IAmountInputViewModel?

    // MARK: - Constructor

    init(
        output: SendViewOutput,
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
        view = SendViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupLocalization()
        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rootView.searchView.textField.becomeFirstResponder()
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
        rootView.actionButton.addTarget(
            self,
            action: #selector(continueButtonClicked),
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
        rootView.pasteButton.addTarget(
            self,
            action: #selector(pasteButtonClicked),
            for: .touchUpInside
        )

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(selectNetworkClicked))
        rootView.selectNetworkView.addGestureRecognizer(tapGesture)

        rootView.amountView.selectHandler = { [weak self] in
            self?.output.didTapSelectAsset()
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountView.textField.inputAccessoryView = accessoryView
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.actionButton.set(enabled: isEnabled)
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

    @objc private func pasteButtonClicked() {
        output.didTapPasteButton()
    }

    @objc private func historyButtonClicked() {
        output.didTapHistoryButton()
    }

    @objc private func selectNetworkClicked() {
        output.didTapSelectNetwork()
    }
}

// MARK: - SendViewInput

extension SendViewController: SendViewInput {
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
        rootView.actionButton.applyDisabledStyle()
        rootView.actionButton.isEnabled = false
    }

    func didStopFeeCalculation() {
        updateActionButton()
    }

    func didStopTipCalculation() {
        updateActionButton()
    }

    func didReceive(viewModel: RecipientViewModel) {
        rootView.bind(viewModel: viewModel)
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
            guard let text = textField.text as NSString? else {
                return true
            }
            let newString = text.replacingCharacters(in: range, with: string)
            output.searchTextDidChanged(newString)
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
    }

    func textFieldDidEndEditing(_: UITextField) {
        rootView.amountView.set(highlighted: false, animated: false)
        rootView.searchView.set(highlighted: false, animated: false)
    }
}

extension SendViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountView.textField.resignFirstResponder()

        output.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
    }
}

extension SendViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        output.updateAmount(amount)
    }
}

// MARK: - Localizable

extension SendViewController: Localizable {
    func applyLocalization() {}
}

extension SendViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
