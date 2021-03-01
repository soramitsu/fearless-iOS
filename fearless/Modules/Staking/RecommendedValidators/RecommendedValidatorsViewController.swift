import UIKit
import SoraUI

final class RecommendedValidatorsViewController: UIViewController {
    var presenter: RecommendedValidatorsPresenterProtocol!

    @IBOutlet private var sectionTitleLabel: UILabel!
    @IBOutlet private var algoDetailsLabel: UILabel!

    @IBOutlet private var hint1: ImageWithTitleView!
    @IBOutlet private var hint2: ImageWithTitleView!
    @IBOutlet private var hint3: ImageWithTitleView!
    @IBOutlet private var hint4: ImageWithTitleView!

    @IBOutlet private var validatorsContainer: UIView!
    @IBOutlet private var validatorsCell: DetailsTriangularedView!
    @IBOutlet private var validatorsCountLabel: UILabel!

    @IBOutlet private var customValidatorsContainer: UIView!
    @IBOutlet private var customValidatorsCell: DetailsTriangularedView!

    @IBOutlet private var warningLabel: UILabel!
    @IBOutlet private var continueButton: TriangularedButton!

    @IBOutlet private var activityView: UIActivityIndicatorView!

    private var viewModel: RecommendedViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        updateLoadingState()
        updateRecommended()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = localizationManager?.selectedLocale.rLanguages

        title = R.string.localizable.stakingRecommendedTitle(preferredLanguages: languages)
        sectionTitleLabel.text = R.string.localizable
            .stakingRecommendedSectionTitle(preferredLanguages: languages)
        algoDetailsLabel.text = R.string.localizable
            .stakingRecommendedSectionDesc(preferredLanguages: languages)
        hint1.title = R.string.localizable.stakingRecommendedHint1(preferredLanguages: languages)
        hint2.title = R.string.localizable.stakingRecommendedHint2(preferredLanguages: languages)
        hint3.title = R.string.localizable.stakingRecommendedHint3(preferredLanguages: languages)
        hint4.title = R.string.localizable.stakingRecommendedHint4(preferredLanguages: languages)

        validatorsCell.title = R.string.localizable
            .stakingRecommendedValidatorsTitle(preferredLanguages: languages)

        customValidatorsCell.title = R.string.localizable
            .stakingRecommendedCustomTitle(preferredLanguages: languages)

        warningLabel.text = R.string.localizable
            .stakingRecommendedWarning(preferredLanguages: languages)

        continueButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: languages)
        continueButton.invalidateLayout()

        updateRecommended()
    }

    private func updateLoadingState() {
        let isViewModelSet = (viewModel != nil)

        validatorsContainer.isHidden = !isViewModelSet
        customValidatorsContainer.isHidden = !isViewModelSet
        continueButton.isEnabled = isViewModelSet

        if isViewModelSet {
            activityView.stopAnimating()
        } else {
            activityView.startAnimating()
        }
    }

    private func updateRecommended() {
        if let viewModel = viewModel {
            let languages = localizationManager?.selectedLocale.rLanguages
            let text = R.string.localizable
                .stakingRecommendedValidatorsCounter("\(viewModel.selectedCount)",
                                                     "\(viewModel.totalCount)",
                                                     preferredLanguages: languages)
            validatorsCountLabel.text = text
        } else {
            validatorsCountLabel.text = ""
        }
    }

    @IBAction private func actionRecommendedValidators() {
        presenter.selectRecommendedValidators()
    }

    @IBAction private func actionCustomValidators() {
        presenter.selectCustomValidators()
    }

    @IBAction private func actionContinue() {
        presenter.proceed()
    }
}

extension RecommendedValidatorsViewController: RecommendedValidatorsViewProtocol {
    func didReceive(viewModel: RecommendedViewModelProtocol) {
        self.viewModel = viewModel

        updateLoadingState()
        updateRecommended()
    }
}

extension RecommendedValidatorsViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
