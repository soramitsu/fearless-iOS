import UIKit
import SoraFoundation

final class StakingRedeemConfirmationViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingRedeemConfirmationLayout

    let presenter: StakingRedeemConfirmationPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var confirmationViewModel: StakingRedeemConfirmationViewModel?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var hintsViewModel: LocalizableResource<[TitleIconViewModel]>?

    init(
        presenter: StakingRedeemConfirmationPresenterProtocol,
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
        view = StakingRedeemConfirmationLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureActions()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale

        applyAssetViewModel()
        applyFeeViewModel()
        applyConfirmationViewModel()
    }

    private func configureActions() {
        rootView.networkFeeFooterView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func applyAssetViewModel() {
        guard let viewModel = assetViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.bind(assetViewModel: viewModel)
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.bind(feeViewModel: viewModel)
    }

    private func applyConfirmationViewModel() {
        guard let confirmViewModel = confirmationViewModel else {
            return
        }
        rootView.navigationBar.setTitle(confirmViewModel.title.value(for: selectedLocale))
        rootView.bind(confirmationViewModel: confirmViewModel)
    }

    private func applyHints() {
        guard let viewModel = hintsViewModel else {
            return
        }
        rootView.bind(hintViewModels: viewModel.value(for: selectedLocale))
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }
}

extension StakingRedeemConfirmationViewController: StakingRedeemConfirmationViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRedeemConfirmationViewModel) {
        confirmationViewModel = viewModel
        applyConfirmationViewModel()
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAssetViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFeeViewModel()
    }

    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>) {
        hintsViewModel = viewModel
        applyHints()
    }
}

extension StakingRedeemConfirmationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
