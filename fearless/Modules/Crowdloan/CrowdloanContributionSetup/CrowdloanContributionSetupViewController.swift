import UIKit
import CommonWallet
import SoraFoundation

final class CrowdloanContributionSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanContributionSetupViewLayout

    let presenter: CrowdloanContributionSetupPresenterProtocol

    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var ethereumAddressViewModel: InputViewModelProtocol?

    var uiFactory: UIFactoryProtocol = UIFactory.default

    init(
        presenter: CrowdloanContributionSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
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
        view = CrowdloanContributionSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBalanceAccessoryView()
        setupAmountInputView()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale
    }

    private func setupAmountInputView() {
        rootView.amountInputView.textField.delegate = self

        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = uiFactory.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private var isFormValid: Bool {
        let ethereumValid = !(ethereumAddressViewModel?.inputHandler.value.isEmpty ?? true) ? ethereumAddressViewModel?.inputHandler.completed : true
        return [amountInputViewModel?.isValid, ethereumValid]
            .compactMap { $0 }
            .allSatisfy { $0 }
    }

    private func updateActionButton() {
        rootView.actionButton.set(enabled: isFormValid)
    }

    @objc func actionProceed() {
        presenter.proceed()
    }

    @objc func actionLearMore() {
        presenter.presentLearnMore()
    }

    @objc func actionBonuses() {
        presenter.presentAdditionalBonuses()
    }
}

extension CrowdloanContributionSetupViewController: CrowdloanContributionSetupViewProtocol {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol) {
        rootView.bind(assetViewModel: viewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: viewModel)
    }

    func didReceiveInput(viewModel: AmountInputViewModelProtocol) {
        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = viewModel
        amountInputViewModel?.observable.add(observer: self)

        rootView.amountInputView.fieldText = amountInputViewModel?.displayAmount

        updateActionButton()
    }

    func didReceiveEthereumAddress(viewModel: InputViewModelProtocol) {
        ethereumAddressViewModel?.inputHandler.removeObserver(self)

        ethereumAddressViewModel = viewModel
        ethereumAddressViewModel?.inputHandler.addObserver(self)

        updateActionButton()
    }

    func didReceiveCrowdloan(viewModel: CrowdloanContributionSetupViewModel) {
        title = viewModel.title
        rootView.bind(crowdloanViewModel: viewModel)

        if let learnMoreView = rootView.learnMoreView {
            learnMoreView.addTarget(self, action: #selector(actionLearMore), for: .touchUpInside)
        }
    }

    func didReceiveEstimatedReward(viewModel: String?) {
        rootView.bind(estimatedReward: viewModel)
    }

    func didReceiveBonus(viewModel: String?) {
        rootView.bind(bonus: viewModel)

        if let bonusView = rootView.bonusView {
            bonusView.addTarget(self, action: #selector(actionBonuses), for: .touchUpInside)
        }
    }

    func didReceiveCustomCrowdloanFlow(viewModel: CustomCrowdloanFlow?) {
        rootView.bind(customFlow: viewModel)

        switch viewModel {
        case .moonbeam:
            rootView.ethereumAddressForRewardView?.ethereumAddressView.animatedInputField.textField.delegate = self
        default:
            break
        }
    }
}

extension CrowdloanContributionSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension CrowdloanContributionSetupViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountInputView.fieldText = amountInputViewModel?.displayAmount

        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension CrowdloanContributionSetupViewController: InputHandlingObserver {
    func didChangeInputValue(_ handler: InputHandling, from _: String) {
        presenter.updateEthereumAddress(handler.value)
    }
}

extension CrowdloanContributionSetupViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField === rootView.amountInputView.textField {
            return amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
        }

        if textField === rootView.ethereumAddressForRewardView?.ethereumAddressView.animatedInputField.textField {
            return ethereumAddressViewModel?.inputHandler.didReceiveReplacement(string, for: range) ?? false
        }

        return false
    }
}

extension CrowdloanContributionSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
