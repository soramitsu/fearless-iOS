import UIKit
import SoraFoundation

final class StakingPoolStartViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingPoolStartViewLayout

    // MARK: Private properties

    private let output: StakingPoolStartViewOutput

    // MARK: - Constructor

    init(
        output: StakingPoolStartViewOutput,
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
        view = StakingPoolStartViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )

        rootView.whatIsStakingView.actionButton?.addTarget(
            self,
            action: #selector(watchAboutButtonClicked),
            for: .touchUpInside
        )

        rootView.joinButton.addTarget(
            self,
            action: #selector(joinPoolButtonClicked),
            for: .touchUpInside
        )

        rootView.createButton.addTarget(
            self,
            action: #selector(createPoolButtonClicked),
            for: .touchUpInside
        )

        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    // MARK: - Private methods

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func watchAboutButtonClicked() {
        output.didTapWatchAboutButton()
    }

    @objc private func joinPoolButtonClicked() {
        output.didTapJoinPoolButton()
    }

    @objc private func createPoolButtonClicked() {
        output.didTapCreatePoolButton()
    }
}

// MARK: - StakingPoolStartViewInput

extension StakingPoolStartViewController: StakingPoolStartViewInput {
    func didReceive(locale: Locale) {
        rootView.locale = locale
        applyLocalization()
    }

    func didReceive(viewModel: StakingPoolStartViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension StakingPoolStartViewController: Localizable {
    func applyLocalization() {
        title = R.string.localizable.poolStakingTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}
