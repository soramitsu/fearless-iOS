import UIKit
import CommonWallet
import SoraFoundation

final class WalletSendViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletSendViewLayout

    let presenter: WalletSendPresenterProtocol

    private var isFirstLayoutCompleted: Bool = false

    private var assetBalanceViewModel: AssetBalanceViewModelProtocol?
    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var feeViewModel: BalanceViewModelProtocol?
    private var tipViewModel: TipViewModel?

    init(presenter: WalletSendPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletSendViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBalanceAccessoryView()
        setupAmountInputView()
        setupLocalization()
        presenter.setup()

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        isFirstLayoutCompleted = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale
    }

    private func setupAmountInputView() {
        rootView.amountView.textField.delegate = self

        rootView.actionButton.addTarget(self, action: #selector(continueButtonClicked), for: .touchUpInside)
    }

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountView.textField.inputAccessoryView = accessoryView
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.actionButton.set(enabled: isEnabled)
    }

    @objc private func continueButtonClicked() {
        presenter.didTapContinueButton()
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }
}

extension WalletSendViewController: WalletSendViewProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?) {
        if let assetViewModel = assetBalanceViewModel {
            rootView.bind(assetViewModel: assetViewModel)
        }
    }

    func didReceive(amountInputViewModel: AmountInputViewModelProtocol?) {
        self.amountInputViewModel = amountInputViewModel
        if let amountViewModel = amountInputViewModel {
            amountViewModel.observable.remove(observer: self)
            amountViewModel.observable.add(observer: self)
            rootView.amountView.inputFieldText = amountViewModel.displayAmount
        }
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
}

extension WalletSendViewController: HiddableBarWhenPushed {}

extension WalletSendViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension WalletSendViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
    }
}

extension WalletSendViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension WalletSendViewController: Localizable {
    func applyLocalization() {}
}

extension WalletSendViewController: KeyboardViewAdoptable {
    var target: UIView? { rootView.actionButton }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
