import UIKit
import SoraFoundation
import CommonWallet

final class StakingUnbondSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingUnbondSetupLayout

    let presenter: StakingUnbondSetupPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingUnbondSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    var uiFactory: UIFactoryProtocol = UIFactory()

    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var bondingDurationViewModel: LocalizableResource<TitleWithSubtitleViewModel>?
    private var feeViewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?
    private var hintsViewModel: LocalizableResource<[TitleIconViewModel]>?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingUnbondSetupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupAmountInputView()
        setupLocalization()
        updateActionButton()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale

        setupBalanceAccessoryView()

        applyAssetViewModel()
        applyFeeViewModel()
        applyBondingDuration()
    }

    private func setupAmountInputView() {
        rootView.amountInputView.textField.delegate = self

        rootView.networkFeeFooterView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )
    }

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = uiFactory.createAmountAccessoryView(for: self, locale: locale)
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

    private func applyAssetViewModel() {
        guard let viewModel = assetViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.amountInputView.bind(viewModel: viewModel)
    }

    private func applyFeeViewModel() {
        if let fee = feeViewModel?.value(for: selectedLocale) {
            rootView.bind(feeViewModel: fee)
        }
    }

    private func applyBondingDuration() {
        guard let viewModel = bondingDurationViewModel else {
            return
        }

        rootView.networkFeeFooterView.bindDuration(viewModel: viewModel)
    }

    private func applyHints() {
        guard let viewModel = hintsViewModel else {
            return
        }
        rootView.bind(hintViewModels: viewModel.value(for: selectedLocale))
    }

    @objc private func actionClose() {
        presenter.close()
    }

    @objc private func actionProceed() {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.proceed()
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.networkFeeFooterView.actionButton.set(enabled: isEnabled)
    }
}

extension StakingUnbondSetupViewController: StakingUnbondSetupViewProtocol {
    func didReceiveAccount(viewModel: AccountViewModel) {
        rootView.accountView.isHidden = false
        rootView.accountView.title = viewModel.title
        rootView.accountView.subtitle = viewModel.name

        let iconSize = 2.0 * rootView.accountView.iconRadius

        rootView.accountView.iconImage = viewModel.icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )
    }

    func didReceiveCollator(viewModel: AccountViewModel) {
        rootView.collatorView.isHidden = false
        rootView.collatorView.title = viewModel.title
        rootView.collatorView.subtitle = viewModel.name

        let iconSize = 2.0 * rootView.collatorView.iconRadius

        rootView.collatorView.iconImage = viewModel.icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAssetViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFeeViewModel()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = viewModel.value(for: selectedLocale)
        amountInputViewModel?.observable.add(observer: self)

        rootView.amountInputView.inputFieldText = amountInputViewModel?.displayAmount

        updateActionButton()
    }

    func didReceiveBonding(duration: LocalizableResource<TitleWithSubtitleViewModel>) {
        bondingDurationViewModel = duration
        applyBondingDuration()
    }

    func didReceiveTitle(viewModel: LocalizableResource<String>) {
        title = viewModel.value(for: selectedLocale)
    }

    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>) {
        hintsViewModel = viewModel
        applyHints()
    }
}

extension StakingUnbondSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension StakingUnbondSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension StakingUnbondSetupViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        rootView.amountInputView.inputFieldText = amountInputViewModel?.displayAmount

        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingUnbondSetupViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}
