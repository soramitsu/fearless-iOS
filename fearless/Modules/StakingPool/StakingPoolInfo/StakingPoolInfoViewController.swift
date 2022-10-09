import UIKit
import SoraFoundation

final class StakingPoolInfoViewController: UIViewController, ViewHolder {
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
    }

    // MARK: - Private methods

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }

    @objc private func validatorsClicked() {
        output.didTapValidators()
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
