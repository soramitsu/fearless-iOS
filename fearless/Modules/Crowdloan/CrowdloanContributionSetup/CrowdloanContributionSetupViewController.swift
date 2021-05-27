import UIKit
import CommonWallet
import SoraFoundation

final class CrowdloanContributionSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanContributionSetupViewLayout

    let presenter: CrowdloanContributionSetupPresenterProtocol

    private var amountInputViewModel: AmountInputViewModelProtocol?

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

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.actionButton.isEnabled = isEnabled
    }

    @objc func actionProceed() {
        presenter.proceed()
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

    func didReceiveCrowdloan(viewModel: CrowdloanContributionViewModel) {
        title = viewModel.title
        rootView.bind(crowdloanViewModel: viewModel)
    }

    func didReceiveEstimatedReward(viewModel: String?) {
        rootView.bind(estimatedReward: viewModel)
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

extension CrowdloanContributionSetupViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension CrowdloanContributionSetupViewController: Localizable {
    func applyLocalization() {
        if isSetup {}
    }
}
