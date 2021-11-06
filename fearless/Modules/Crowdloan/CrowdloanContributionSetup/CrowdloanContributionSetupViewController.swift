import UIKit
import CommonWallet
import SoraFoundation
import SoraUI

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
        [amountInputViewModel?.isValid, ethereumAddressViewModel?.inputHandler.completed]
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

        rootView.ethereumAddressForRewardView?.ethereumAddressView.animatedInputField.text = viewModel.inputHandler.value

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
        if case .moonbeam = viewModel {
            rootView.ethereumAddressForRewardView?.ethereumAddressView.animatedInputField.delegate = self
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

extension CrowdloanContributionSetupViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func animatedTextField(
        _: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        _ = ethereumAddressViewModel?.inputHandler.didReceiveReplacement(string, for: range)
        return false
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

        return true
    }
}

extension CrowdloanContributionSetupViewController: Localizable {
    func applyLocalization() {
        if isSetup {}
    }
}
