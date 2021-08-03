import UIKit
import SoraFoundation
import CommonWallet

final class StakingBondMoreViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingBondMoreViewLayout

    let presenter: StakingBondMorePresenterProtocol

    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingBondMorePresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingBondMoreViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAmountInputView()
        setupActionButton()
        applyLocalization()
        presenter.setup()
    }

    private func setupAmountInputView() {
        rootView.amountInputView.textField.keyboardType = .decimalPad
        rootView.amountInputView.textField.delegate = self

        let accessoryView = UIFactory().createAmountAccessoryView(for: self, locale: selectedLocale)
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupActionButton() {
        rootView.actionButton.addTarget(self, action: #selector(handleActionButton), for: .touchUpInside)
    }

    @objc
    private func handleActionButton() {
        presenter.handleContinueAction()
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.actionButton.isEnabled = isEnabled
    }

    private func applyAsset() {
        if let viewModel = assetViewModel?.value(for: selectedLocale) {
            rootView.amountInputView.balanceText = R.string.localizable
                .commonAvailableFormat(
                    viewModel.balance ?? "",
                    preferredLanguages: selectedLocale.rLanguages
                )
            rootView.amountInputView.priceText = viewModel.price
            rootView.amountInputView.assetIcon = viewModel.icon
            rootView.amountInputView.symbol = viewModel.symbol
        }
    }

    private func applyFee() {
        if let fee = feeViewModel?.value(for: selectedLocale) {
            rootView.networkFeeView.bind(viewModel: fee)
        }
    }
}

extension StakingBondMoreViewController: StakingBondMoreViewProtocol {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()

        updateActionButton()
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAsset()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        let concreteViewModel = viewModel.value(for: selectedLocale)

        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = concreteViewModel

        rootView.amountInputView.fieldText = concreteViewModel.displayAmount
        concreteViewModel.observable.add(observer: self)

        updateActionButton()
    }
}

extension StakingBondMoreViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingBondMore_v190(preferredLanguages: selectedLocale.rLanguages)
            rootView.locale = selectedLocale
        }
    }
}

extension StakingBondMoreViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension StakingBondMoreViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountInputView.fieldText = amountInputViewModel?.displayAmount

        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingBondMoreViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}
