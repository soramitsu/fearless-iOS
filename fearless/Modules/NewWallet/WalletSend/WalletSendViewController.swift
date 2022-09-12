import UIKit
import CommonWallet
import SoraFoundation

final class WalletSendViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletSendViewLayout

    let presenter: WalletSendPresenterProtocol

    private var state: WalletSendViewState = .loading
    private var isFirstLayoutCompleted: Bool = false

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

    private func applyState(_ state: WalletSendViewState) {
        self.state = state

        switch state {
        case .loading:
            break
        case let .loaded(model):
            rootView.bind(scamInfo: model.scamInfo)
            rootView.bind(feeViewModel: model.feeViewModel)
            rootView.bind(tipViewModel: model.tipViewModel, isRequired: model.tipRequired)

            if let assetViewModel = model.assetBalanceViewModel {
                rootView.bind(assetViewModel: assetViewModel)
            }

            if let amountViewModel = model.amountInputViewModel {
                amountViewModel.observable.remove(observer: self)
                amountViewModel.observable.add(observer: self)
                rootView.amountView.fieldText = amountViewModel.displayAmount
            }
        }
    }

    private func updateActionButton() {
        guard case let .loaded(viewModel) = state else {
            return
        }
        let isEnabled = (viewModel.amountInputViewModel?.isValid == true)
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
    func didReceive(state: WalletSendViewState) {
        applyState(state)
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
        guard case let .loaded(viewModel) = state else {
            return false
        }

        return viewModel.amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
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
        guard case let .loaded(viewModel) = state else {
            return
        }

        rootView.amountView.fieldText = viewModel.amountInputViewModel?.displayAmount

        let amount = viewModel.amountInputViewModel?.decimalAmount ?? 0.0
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
