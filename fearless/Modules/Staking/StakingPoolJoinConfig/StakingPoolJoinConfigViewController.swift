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

        navigationController?.setNavigationBarHidden(true, animated: true)

        setupBalanceAccessoryView()
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
        self.amountInputViewModel = amountInputViewModel
        amountInputViewModel.observable.remove(observer: self)
        amountInputViewModel.observable.add(observer: self)
        rootView.amountView.fieldText = amountInputViewModel.displayAmount
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
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
        rootView.amountView.fieldText = amountInputViewModel?.displayAmount

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        output.updateAmount(amount)
    }
}
