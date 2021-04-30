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

        setupInitBalanceView()
        applyLocalization()
        presenter.setup()
    }

    private func setupInitBalanceView() {
        rootView.amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: selectedLocale.rLanguages)
        rootView.amountInputView.priceText = "$2,524.1"
        rootView.amountInputView.symbol = "KSM"
        rootView.amountInputView.assetIcon = R.image.iconKsmSmallBg()
        rootView.amountInputView.balanceText = "Bonded: 10.00003"

        let textColor = R.color.colorWhite()!
        let placeholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: textColor.withAlphaComponent(0.5),
                .font: UIFont.h4Title
            ]
        )

        rootView.amountInputView.textField.attributedPlaceholder = placeholder
        rootView.amountInputView.textField.keyboardType = .decimalPad
        rootView.amountInputView.textField.delegate = self
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.continueButton.isEnabled = isEnabled
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
            rootView.networkFeeView.bind(tokenAmount: fee.amount, fiatAmount: fee.price)
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
                .stakingBondMore(preferredLanguages: selectedLocale.rLanguages)
            rootView.locale = selectedLocale
        }
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
