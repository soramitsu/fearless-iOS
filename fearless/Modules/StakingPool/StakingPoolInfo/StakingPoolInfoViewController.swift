import UIKit
import SoraFoundation

final class StakingPoolInfoViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = StakingPoolInfoViewLayout

    // MARK: Private properties

    private let output: StakingPoolInfoViewOutput

    // MARK: - Constructor

    init(
        output: StakingPoolInfoViewOutput,
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
        view = StakingPoolInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        let tapGesture = UITapGestureRecognizer()
        tapGesture.addTarget(self, action: #selector(validatorsClicked))
        rootView.validatorsView.addGestureRecognizer(tapGesture)

        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        output.willAppear(view: self)
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.roleNominatorView.addTarget(
            self,
            action: #selector(handleNominationTapped),
            for: .touchUpInside
        )
        rootView.roleStateTogglerView.addTarget(
            self,
            action: #selector(handleStateTogglerTapped),
            for: .touchUpInside
        )
        rootView.roleRootView.addTarget(
            self,
            action: #selector(handleRootTapped),
            for: .touchUpInside
        )
        rootView.saveRolesButton.addTarget(
            self,
            action: #selector(saveRolesTapped),
            for: .touchUpInside
        )
    }

    @objc private func saveRolesTapped() {
        output.saveRolesDidTapped()
    }

    @objc private func handleNominationTapped() {
        output.nominatorDidTapped()
    }

    @objc private func handleStateTogglerTapped() {
        output.stateTogglerDidTapped()
    }

    @objc private func handleRootTapped() {
        output.rootDidTapped()
    }

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }

    @objc private func validatorsClicked() {
        output.didTapValidators()
    }

    // MARK: - LoadableViewProtocol

    var loadableContentView: UIView! {
        rootView.contentView
    }
}

// MARK: - StakingPoolInfoViewInput

extension StakingPoolInfoViewController: StakingPoolInfoViewInput {
    func didReceive(viewModel: StakingPoolInfoViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension StakingPoolInfoViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
