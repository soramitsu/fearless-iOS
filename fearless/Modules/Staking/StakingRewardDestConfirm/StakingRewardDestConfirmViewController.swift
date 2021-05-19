import UIKit
import SoraFoundation

final class StakingRewardDestConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardDestConfirmViewLayout

    let presenter: StakingRewardDestConfirmPresenterProtocol

    private var confirmationViewModel: StakingRewardDestConfirmViewModel?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    init(
        presenter: StakingRewardDestConfirmPresenterProtocol,
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
        view = StakingRewardDestConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    private func configure() {
        rootView.senderAccountView.addTarget(self, action: #selector(actionSenderAccount), for: .touchUpInside)
        rootView.networkFeeConfirmView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonConfirmTitle(preferredLanguages: languages)

        rootView.locale = selectedLocale

        applyFeeViewModel()
        applyConfirmationViewModel()
    }

    private func applyFeeViewModel() {
        guard let feeViewModel = feeViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.bind(feeViewModel: feeViewModel)
    }

    private func applyConfirmationViewModel() {
        guard let viewModel = confirmationViewModel else {
            return
        }

        rootView.bind(confirmationViewModel: viewModel)

        if
            let payoutAccount = rootView.payoutAccountView,
            payoutAccount.actions(forTarget: self, forControlEvent: .touchUpInside) == nil {
            payoutAccount.addTarget(self, action: #selector(actionPayoutAccount), for: .touchUpInside)
        }
    }

    @objc private func actionSenderAccount() {
        presenter.presentSenderAccountOptions()
    }

    @objc private func actionPayoutAccount() {
        presenter.presentPayoutAccountOptions()
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }
}

extension StakingRewardDestConfirmViewController: StakingRewardDestConfirmViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRewardDestConfirmViewModel) {
        confirmationViewModel = viewModel

        applyConfirmationViewModel()
    }

    func didReceiveFeeViewModel(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel

        applyFeeViewModel()
    }
}

extension StakingRewardDestConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
