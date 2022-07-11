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
        setupLocalization()
        updateLoadingState()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.updateOnAppearance()
    }

    private func configure() {
        rootView.recommendedValidatorsCell.addTarget(
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

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.recommendedValidatorsCell.rowContentView.titleLabel.text = R.string.localizable
            .stakingSelectValidatorsRecommendedButtonTitle(preferredLanguages: languages)

        switch phase {
        case .setup:
            rootView.customValidatorsCell.rowContentView.titleLabel.text = R.string.localizable
                .stakingSelectValidatorsCustomButtonTitle(preferredLanguages: selectedLocale.rLanguages)
        case .update:
            rootView.customValidatorsCell.rowContentView.titleLabel.text = R.string.localizable
                .stakingCustomValidatorsUpdateList(preferredLanguages: selectedLocale.rLanguages)
        }

        updateSelected()
    }

    private func toggleActivityViews() {
        (viewModel?.recommendedValidatorListLoaded ?? false)
            ? rootView.recommendedValidatorsActivityIndicator.stopAnimating()
            : rootView.recommendedValidatorsActivityIndicator.startAnimating()

        viewModelIsSet
            ? rootView.customValidatorsActivityIndicator.stopAnimating()
            : rootView.customValidatorsActivityIndicator.startAnimating()
    }

    private func toggleNextStepIndicators() {
        let recommendedValidatorListLoaded = (viewModel?.recommendedValidatorListLoaded ?? false)
        rootView.recommendedValidatorsCell.rowContentView.arrowIconView.isHidden = !recommendedValidatorListLoaded
        rootView.customValidatorsCell.rowContentView.arrowIconView.isHidden = !viewModelIsSet
    }

    func updateLoadingState() {
        toggleActivityViews()
        toggleNextStepIndicators()
    }

    private func updateSelected() {
        guard let viewModel = viewModel else {
            rootView.customValidatorsCell.rowContentView.detailsLabel.text = ""
            return
        }

        if let totalCount = viewModel.totalCount {
            if viewModel.selectedCount > 0 {
                let languages = selectedLocale.rLanguages
                let text = R.string.localizable
                    .stakingValidatorInfoNominators(
                        "\(viewModel.selectedCount)",
                        "\(totalCount)",
                        preferredLanguages: languages
                    )
                rootView.customValidatorsCell.rowContentView.detailsLabel.text = text
            } else {
                rootView.customValidatorsCell.rowContentView.detailsLabel.text = ""
            }
        } else {
            if viewModel.selectedCount > 0 {
                rootView.customValidatorsCell.rowContentView.detailsLabel.text = "\(viewModel.selectedCount)"
            } else {
                rootView.customValidatorsCell.rowContentView.detailsLabel.text = ""
            }
        }
    }

    @objc private func actionRecommendedValidators() {
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
            self.updateSelected()
        }
    }

    func didReceive(textsViewModel: SelectValidatorsStartTextsViewModel) {
        title = textsViewModel.stakingRecommendedTitle
        rootView.algoSectionLabel.text = textsViewModel.algoSectionLabel
        rootView.algoDetailsLabel.text = textsViewModel.algoDetailsLabel
        rootView.suggestedValidatorsWarningView.titleLabel.text = textsViewModel.suggestedValidatorsWarningViewTitle
        rootView.customValidatorsSectionLabel.text = textsViewModel.customValidatorsSectionLabel
        rootView.customValidatorsDetailsLabel.text = textsViewModel.customValidatorsDetailsLabel

        rootView.setAlgoSteps(
            textsViewModel.algoSteps
        )
    }
}

extension SelectValidatorsStartViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
