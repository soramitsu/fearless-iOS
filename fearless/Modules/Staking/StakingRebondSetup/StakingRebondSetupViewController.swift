import UIKit
import SoraFoundation
import CommonWallet

final class StakingRebondSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRebondSetupLayout

    let presenter: StakingRebondSetupPresenterProtocol

    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var uiFactory: UIFactoryProtocol = UIFactory()

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingRebondSetupPresenterProtocol,
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
        view = StakingRebondSetupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupAmountInputView()
        setupActionButton()
        setupLocalization()
        updateActionButton()

        presenter.setup()
    }

    // MARK: - Setup routine

    private func setupAmountInputView() {
        rootView.amountInputView.textField.delegate = self
    }

    private func setupActionButton() {
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    private func setupBalanceAccessoryView() {
        let accessoryView = uiFactory.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupNavigationItem() {
        let closeBarItem = UIBarButtonItem(
            image: R.image.iconClose(),
            style: .plain,
            target: self,
            action: #selector(actionClose)
        )

        navigationItem.leftBarButtonItem = closeBarItem
    }

    // MARK: - View changes

    private func applyAssetViewModel() {
        guard let viewModel = assetViewModel?.value(for: selectedLocale) else {
            return
        }

        let amountView = rootView.amountInputView
        amountView.priceText = viewModel.price

        if let balance = viewModel.balance {
            amountView.balanceText = R.string.localizable.stakingUnbondingFormat(
                balance,
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            amountView.balanceText = nil
        }

        amountView.assetIcon = viewModel.icon
        amountView.symbol = viewModel.symbol.uppercased()
    }

    private func applyFeeViewModel() {
        guard let viewModel = feeViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.actionButton.isEnabled = isEnabled
    }

    // MARK: - Actions

    @objc private func actionClose() {
        presenter.close()
    }

    @objc private func actionProceed() {
        rootView.amountInputView.textField.resignFirstResponder()
        presenter.proceed()
    }
}

extension StakingRebondSetupViewController: Localizable {
    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.stakingRebond(preferredLanguages: languages)

        rootView.locale = selectedLocale

        setupBalanceAccessoryView()

        applyAssetViewModel()
        applyFeeViewModel()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingRebondSetupViewController: StakingRebondSetupViewProtocol {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAssetViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFeeViewModel()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = viewModel.value(for: selectedLocale)
        amountInputViewModel?.observable.add(observer: self)

        rootView.amountInputView.fieldText = amountInputViewModel?.displayAmount

        updateActionButton()
    }
}

extension StakingRebondSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension StakingRebondSetupViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountInputView.fieldText = amountInputViewModel?.displayAmount

        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingRebondSetupViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}
