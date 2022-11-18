import UIKit
import SoraFoundation

final class PoolRolesConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = PoolRolesConfirmViewLayout

    // MARK: Private properties

    private let output: PoolRolesConfirmViewOutput

    // MARK: - Constructor

    init(
        output: PoolRolesConfirmViewOutput,
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
        view = PoolRolesConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.confirmButton.addTarget(
            self,
            action: #selector(confirmButtonClicked),
            for: .touchUpInside
        )

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func confirmButtonClicked() {
        output.didTapConfirmButton()
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }
}

// MARK: - PoolRolesConfirmViewInput

extension PoolRolesConfirmViewController: PoolRolesConfirmViewInput {
    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }

    func didReceive(viewModel: PoolRolesConfirmViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension PoolRolesConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
