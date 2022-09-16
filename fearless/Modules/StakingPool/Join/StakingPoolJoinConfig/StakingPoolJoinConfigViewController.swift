import UIKit
import SoraFoundation
import CommonWallet

final class StakingPoolJoinConfigViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingPoolJoinConfigViewLayout

    // MARK: Private properties

    private let output: StakingPoolJoinConfigViewOutput
    private var amountInputViewModel: AmountInputViewModelProtocol?

    // MARK: - Constructor

    init(
        output: StakingPoolJoinConfigViewOutput,
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
        view = StakingPoolJoinConfigViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )
        rootView.feeView.actionButton.addTarget(
            self,
            action: #selector(continueButtonClicked),
            for: .touchUpInside
        )

        navigationController?.setNavigationBarHidden(true, animated: true)
        setupBalanceAccessoryView()

        rootView.amountView.textField.delegate = self

        applyLocalization()
    }

    // MARK: - Private methods

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountView.textField.inputAccessoryView = accessoryView
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func continueButtonClicked() {
        output.didTapContinueButton()
    }
}

// MARK: - StakingPoolJoinConfigViewInput

extension StakingPoolJoinConfigViewController: StakingPoolJoinConfigViewInput {
    func didReceiveAccountViewModel(_ accountViewModel: AccountViewModel) {
        rootView.bind(accountViewModel: accountViewModel)
    }

    func didReceiveAssetBalanceViewModel(_ assetBalanceViewModel: AssetBalanceViewModelProtocol) {
        rootView.bind(assetViewModel: assetBalanceViewModel)
    }

    func didReceiveAmountInputViewModel(_ amountInputViewModel: AmountInputViewModelProtocol) {
        rootView.amountView.inputFieldText = amountInputViewModel.displayAmount
        self.amountInputViewModel = amountInputViewModel
        self.amountInputViewModel?.observable.remove(observer: self)

        self.amountInputViewModel?.observable.add(observer: self)
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }

    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?) {
        rootView.feeView.bindBalance(viewModel: feeViewModel)
    }
}

// MARK: - Localizable

extension StakingPoolJoinConfigViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension StakingPoolJoinConfigViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountView.textField.resignFirstResponder()

        output.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountView.textField.resignFirstResponder()
    }
}

extension StakingPoolJoinConfigViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountView.inputFieldText = amountInputViewModel?.displayAmount

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        output.updateAmount(amount)
    }
}

extension StakingPoolJoinConfigViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}
