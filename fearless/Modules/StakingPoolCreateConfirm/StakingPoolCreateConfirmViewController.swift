import UIKit
import SoraFoundation

final class StakingPoolCreateConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingPoolCreateConfirmViewLayout

    // MARK: Private properties

    private let output: StakingPoolCreateConfirmViewOutput

    // MARK: - Constructor

    init(
        output: StakingPoolCreateConfirmViewOutput,
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
        view = StakingPoolCreateConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        navigationController?.setNavigationBarHidden(true, animated: true)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )

        rootView.continueButton.addTarget(
            self,
            action: #selector(confirmButtonClicked),
            for: .touchUpInside
        )
    }

    // MARK: - Private actions

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func confirmButtonClicked() {
        output.didTapConfirmButton()
    }
}

// MARK: - StakingPoolCreateConfirmViewInput

extension StakingPoolCreateConfirmViewController: StakingPoolCreateConfirmViewInput {
    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }

    func didReceive(confirmViewModel: StakingPoolCreateConfirmViewModel) {
        rootView.bind(confirmViewModel: confirmViewModel)
    }
}

// MARK: - Localizable

extension StakingPoolCreateConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
