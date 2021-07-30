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

        title = R.string.localizable.stakingRecommendedTitle(preferredLanguages: languages)
        rootView.algoSectionLabel.text = R.string.localizable
            .stakingSelectValidatorsRecommendedTitle(preferredLanguages: languages)
        rootView.algoDetailsLabel.text = R.string.localizable
            .stakingSelectValidatorsRecommendedDesc(preferredLanguages: languages)

        rootView.setAlgoSteps(
            [
                R.string.localizable.stakingRecommendedHint1(preferredLanguages: languages),
                R.string.localizable.stakingRecommendedHint2(preferredLanguages: languages),
                R.string.localizable.stakingRecommendedHint3(preferredLanguages: languages),
                R.string.localizable.stakingRecommendedHint4(preferredLanguages: languages),
                R.string.localizable.stakingRecommendedHint5(preferredLanguages: languages)
            ]
        )

        rootView.recommendedValidatorsCell.rowContentView.titleLabel.text = R.string.localizable
            .stakingSelectValidatorsRecommendedButtonTitle(preferredLanguages: languages)

        rootView.customValidatorsSectionLabel.text = R.string.localizable
            .stakingSelectValidatorsCustomTitle(preferredLanguages: languages)

        rootView.customValidatorsDetailsLabel.text = R.string.localizable
            .stakingSelectValidatorsCustomDesc(preferredLanguages: languages)

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
        [
            rootView.recommendedValidatorsActivityIndicator,
            rootView.customValidatorsActivityIndicator
        ].forEach { view in
            if viewModelIsSet {
                view.stopAnimating()
            } else {
                view.startAnimating()
            }
        }
    }

    private func toggleNextStepIndicators() {
        [
            rootView.recommendedValidatorsCell.rowContentView.arrowIconView,
            rootView.customValidatorsCell.rowContentView.arrowIconView
        ].forEach { view in
            view.isHidden = !viewModelIsSet
        }
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

        if viewModel.selectedCount > 0 {
            let languages = selectedLocale.rLanguages
            let text = R.string.localizable
                .stakingValidatorInfoNominators(
                    "\(viewModel.selectedCount)",
                    "\(viewModel.totalCount)",
                    preferredLanguages: languages
                )
            rootView.customValidatorsCell.rowContentView.detailsLabel.text = text
        } else {
            rootView.customValidatorsCell.rowContentView.detailsLabel.text = ""
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
    func didReceive(viewModel: SelectValidatorsStartViewModel) {
        self.viewModel = viewModel

        updateLoadingState()
        updateSelected()
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
