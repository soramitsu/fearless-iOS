import UIKit
import SoraUI

final class SelectValidatorsStartViewController: UIViewController {
    var presenter: SelectValidatorsStartPresenterProtocol!

    @IBOutlet private var sectionTitleLabel: UILabel!
    @IBOutlet private var algoDetailsLabel: UILabel!
    @IBOutlet private var customValidatorsTitleLabel: UILabel!
    @IBOutlet private var customValidatorsDetailsLabel: UILabel!

    @IBOutlet private var hint1: ImageWithTitleView!
    @IBOutlet private var hint2: ImageWithTitleView!
    @IBOutlet private var hint3: ImageWithTitleView!
    @IBOutlet private var hint4: ImageWithTitleView!
    @IBOutlet private var hint5: ImageWithTitleView!

    @IBOutlet private var validatorsCell: DetailsTriangularedView!

    @IBOutlet private var customValidatorsCell: DetailsTriangularedView!
    @IBOutlet private var customValidatorsCountLabel: UILabel!

    @IBOutlet private var activityViews: [UIActivityIndicatorView]!
    @IBOutlet private var nextStepIndicators: [UIImageView]!

    private var viewModel: SelectValidatorsStartViewModelProtocol?

    private var viewModelIsSet: Bool {
        viewModel != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        updateLoadingState()
        updateSelected()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.updateOnAppearance()
    }

    private func setupLocalization() {
        let languages = localizationManager?.selectedLocale.rLanguages

        title = R.string.localizable.stakingRecommendedTitle(preferredLanguages: languages)
        sectionTitleLabel.text = R.string.localizable
            .stakingSelectValidatorsRecommendedTitle(preferredLanguages: languages)
        algoDetailsLabel.text = R.string.localizable
            .stakingSelectValidatorsRecommendedDesc(preferredLanguages: languages)
        hint1.title = R.string.localizable.stakingRecommendedHint1(preferredLanguages: languages)
        hint2.title = R.string.localizable.stakingRecommendedHint2(preferredLanguages: languages)
        hint3.title = R.string.localizable.stakingRecommendedHint3(preferredLanguages: languages)
        hint4.title = R.string.localizable.stakingRecommendedHint4(preferredLanguages: languages)
        hint5.title = R.string.localizable.stakingRecommendedHint5(preferredLanguages: languages)

        validatorsCell.title = R.string.localizable
            .stakingSelectValidatorsRecommendedButtonTitle(preferredLanguages: languages)

        customValidatorsTitleLabel.text = R.string.localizable
            .stakingSelectValidatorsCustomTitle(preferredLanguages: languages)

        customValidatorsDetailsLabel.text = R.string.localizable
            .stakingSelectValidatorsCustomDesc(preferredLanguages: languages)

        customValidatorsCell.title = R.string.localizable
            .stakingSelectValidatorsCustomButtonTitle(preferredLanguages: languages)

        updateSelected()
    }

    private func toggleActivityViews() {
        activityViews.forEach { view in
            if viewModelIsSet {
                view.stopAnimating()
            } else {
                view.startAnimating()
            }
        }
    }

    private func toggleNextStepIndicators() {
        nextStepIndicators.forEach { view in
            view.isHidden = !viewModelIsSet
        }
    }

    func updateLoadingState() {
        toggleActivityViews()
        toggleNextStepIndicators()
    }

    private func updateSelected() {
        if let viewModel = viewModel, viewModel.selectedCount > 0 {
            let languages = localizationManager?.selectedLocale.rLanguages
            let text = R.string.localizable
                .stakingRecommendedValidatorsCounter(
                    "\(viewModel.selectedCount)",
                    "\(viewModel.totalCount)",
                    preferredLanguages: languages
                )
            customValidatorsCountLabel.text = text
        } else {
            customValidatorsCountLabel.text = ""
        }
    }

    @IBAction private func actionRecommendedValidators() {
        presenter.selectRecommendedValidators()
    }

    @IBAction private func actionCustomValidators() {
        presenter.selectCustomValidators()
    }
}

extension SelectValidatorsStartViewController: SelectValidatorsStartViewProtocol {
    func didReceive(viewModel: SelectValidatorsStartViewModelProtocol) {
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
