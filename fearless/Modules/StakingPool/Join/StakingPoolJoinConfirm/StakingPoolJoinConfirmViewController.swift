import UIKit
import SoraFoundation

final class StakingPoolJoinConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingPoolJoinConfirmViewLayout

    // MARK: Private properties

    private let output: StakingPoolJoinConfirmViewOutput

    // MARK: - Constructor

    init(
        output: StakingPoolJoinConfirmViewOutput,
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
        view = StakingPoolJoinConfirmViewLayout()
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

    // MARK: - Private methods

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func confirmButtonClicked() {
        output.didTapConfirmButton()
    }
}

// MARK: - StakingPoolJoinConfirmViewInput

extension StakingPoolJoinConfirmViewController: StakingPoolJoinConfirmViewInput {
    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }

    func didReceive(confirmViewModel: StakingPoolJoinConfirmViewModel) {
        rootView.bind(confirmViewModel: confirmViewModel)
    }
}

// MARK: - Localizable

extension StakingPoolJoinConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
