import UIKit
import SoraFoundation

final class StakingBalanceViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingBalanceViewLayout

    let presenter: StakingBalancePresenterProtocol

    init(
        presenter: StakingBalancePresenterProtocol,
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
        view = StakingBalanceViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTitle()
        presenter.setup()

        rootView.balanceWidget.bind(viewModels: [
            .init(title: "Bonded", tokemAmountText: "10.00003 KSM", usdAmountText: "$4,524.1"),
            .init(title: "Unbonding", tokemAmountText: "0.33911 KSM", usdAmountText: "$204"),
            .init(title: "Redeemable", tokemAmountText: "5 KSM", usdAmountText: "$2,250")
        ])
    }

    private func setupTitle() {
        title = "Staking balance" // TODO:
    }
}

extension StakingBalanceViewController: StakingBalanceViewProtocol {
    func applyLocalization() {
        if isViewLoaded {
            setupTitle()
        }
    }
}
