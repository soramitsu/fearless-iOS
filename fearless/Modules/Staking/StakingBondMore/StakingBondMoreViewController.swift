import UIKit
import SoraFoundation

final class StakingBondMoreViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingBondMoreViewLayout

    let presenter: StakingBondMorePresenterProtocol

    private var amountInputViewModel: IAmountInputViewModel?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?

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

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )
    }

    private func setupAmountInputView() {
        rootView.amountInputView.textField.delegate = self

        let accessoryView = UIFactory().createAmountAccessoryView(for: self, locale: selectedLocale)
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupActionButton() {
        rootView.networkFeeFooterView.actionButton.addTarget(
            self,
            action: #selector(handleActionButton),
            for: .touchUpInside
        )
    }

    @objc
    private func handleActionButton() {
        presenter.handleContinueAction()
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.networkFeeFooterView.actionButton.set(enabled: isEnabled)
    }

    private func applyAsset() {
        if let viewModel = assetViewModel?.value(for: selectedLocale) {
            rootView.amountInputView.bind(viewModel: viewModel)
        }
    }

    private func applyFee() {
        let fee = feeViewModel?.value(for: selectedLocale)
        rootView.bind(feeViewModel: fee)
    }
}

extension StakingBondMoreViewController: StakingBondMoreViewProtocol {
    func didReceiveHints(viewModel: LocalizableResource<String>?) {
        if let viewModel = viewModel {
            rootView.hintView.detailsLabel.text = viewModel.value(for: selectedLocale)
            rootView.hintView.isHidden = false
        } else {
            rootView.hintView.isHidden = true
        }
    }

    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()

        updateActionButton()
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAsset()
    }

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
        let concreteViewModel = viewModel.value(for: selectedLocale)

        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = concreteViewModel

        rootView.amountInputView.inputFieldText = concreteViewModel.displayAmount
        concreteViewModel.observable.add(observer: self)

        updateActionButton()
    }

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
            R.color.colorWhite() ?? R.color.colorWhite()!,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )
    }
}

extension StakingBondMoreViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
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
        rootView.amountInputView.inputFieldText = amountInputViewModel?.displayAmount

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
