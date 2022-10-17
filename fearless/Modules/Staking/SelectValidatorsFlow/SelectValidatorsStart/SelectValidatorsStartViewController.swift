import UIKit
import SoraUI
import SoraFoundation

final class SelectValidatorsStartViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    enum Phase {
        case setup
        case update
    }

    typealias RootViewType = SelectValidatorsViewLayout

    let presenter: SelectValidatorsStartPresenterProtocol
    let phase: Phase

    private var viewModel: SelectValidatorsStartViewModel?

    private var viewModelIsSet: Bool {
        viewModel != nil
    }

    init(
        presenter: SelectValidatorsStartPresenterProtocol,
        phase: Phase,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.phase = phase

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SelectValidatorsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        updateLoadingState()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.updateOnAppearance()
    }

    private func configure() {
        rootView.recommendedValidatorsButton.addTarget(
            self,
            action: #selector(actionRecommendedValidators),
            for: .touchUpInside
        )

        rootView.customValidatorsCell.addTarget(
            self,
            action: #selector(actionCustomValidators),
            for: .touchUpInside
        )
    }

    private func toggleActivityViews() {
        let recommendedValidatorListLoaded = (viewModel?.recommendedValidatorListLoaded ?? false)
        rootView.recommendedValidatorsButton.isEnabled = recommendedValidatorListLoaded

        recommendedValidatorListLoaded
            ? rootView.recommendedValidatorsActivityIndicator.stopAnimating()
            : rootView.recommendedValidatorsActivityIndicator.startAnimating()

        rootView.customValidatorsCell.isEnabled = viewModelIsSet
        viewModelIsSet
            ? rootView.customValidatorsActivityIndicator.stopAnimating()
            : rootView.customValidatorsActivityIndicator.startAnimating()
    }

    func updateLoadingState() {
        toggleActivityViews()
    }

    @objc private func actionRecommendedValidators() {
        guard viewModel?.recommendedValidatorListLoaded ?? false else {
            return
        }
        presenter.selectRecommendedValidators()
    }

    @objc private func actionCustomValidators() {
        presenter.selectCustomValidators()
    }
}

extension SelectValidatorsStartViewController: SelectValidatorsStartViewProtocol {
    func didReceive(viewModel: SelectValidatorsStartViewModel?) {
        self.viewModel = viewModel

        DispatchQueue.main.async {
            self.updateLoadingState()
        }
    }

    func didReceive(textsViewModel: SelectValidatorsStartTextsViewModel) {
        title = textsViewModel.stakingRecommendedTitle
        rootView.algoSectionLabel.text = textsViewModel.algoSectionLabel
        rootView.algoDetailsLabel.text = textsViewModel.algoDetailsLabel
        rootView.customValidatorsSectionLabel.text = textsViewModel.customValidatorsSectionLabel
        rootView.customValidatorsDetailsLabel.text = textsViewModel.customValidatorsDetailsLabel

        rootView.setAlgoSteps(
            textsViewModel.algoSteps
        )
    }
}

extension SelectValidatorsStartViewController {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
