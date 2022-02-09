import UIKit
import SoraFoundation

final class CrowdloanContributionConfirmVC: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanContributionConfirmViewLayout

    let presenter: CrowdloanContributionConfirmPresenterProtocol

    init(
        presenter: CrowdloanContributionConfirmPresenterProtocol,
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
        view = CrowdloanContributionConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    private func configure() {
        rootView.accountView.addTarget(self, action: #selector(actionAccountOptions), for: .touchUpInside)
        rootView.networkFeeConfirmView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirmTitle(preferredLanguages: selectedLocale.rLanguages)
        rootView.locale = selectedLocale
    }

    @objc func actionConfirm() {
        presenter.confirm()
    }

    @objc func actionAccountOptions() {
        presenter.presentAccountOptions()
    }
}

extension CrowdloanContributionConfirmVC: CrowdloanContributionConfirmViewProtocol {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol) {
        rootView.bind(assetViewModel: viewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: viewModel)
    }

    func didReceiveCrowdloan(viewModel: CrowdloanContributeConfirmViewModel) {
        rootView.bind(confirmationViewModel: viewModel)
    }

    func didReceiveEstimatedReward(viewModel: String?) {
        rootView.bind(estimatedReward: viewModel)
    }

    func didReceiveBonus(viewModel: String?) {
        rootView.bind(bonus: viewModel)
    }
}

extension CrowdloanContributionConfirmVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
