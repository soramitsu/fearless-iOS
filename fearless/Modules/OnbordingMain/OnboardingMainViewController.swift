import UIKit
import SoraUI

final class OnboardingMainViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    var presenter: OnboardingMainPresenterProtocol!

    @IBOutlet private var termsLabel: UILabel!
    @IBOutlet private var signUpButton: TriangularedButton!
    @IBOutlet private var restoreButton: TriangularedButton!
    @IBOutlet private var logoView: UIImageView!

    @IBOutlet private var restoreBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var restoreWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var signupWidthConstraint: NSLayoutConstraint!

    @IBOutlet private var termsBottomConstraint: NSLayoutConstraint!

    var locale: Locale?

    var termDecorator: AttributedStringDecoratorProtocol?

    // MARK: Appearance

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureLogoView()
        configureTermsLabel()
        adjustLayout()
    }

    private func configureTermsLabel() {
        if let attributedText = termsLabel.attributedText {
            termsLabel.attributedText = termDecorator?.decorate(attributedString: attributedText)
        }
    }

    private func configureLogoView() {
        logoView.tintColor = R.color.colorWhite()!
    }

    private func setupLocalization() {
        signUpButton.imageWithTitleView?.title = R.string.localizable
            .onboardingCreateAccount(preferredLanguages: locale?.rLanguages)
        restoreButton.imageWithTitleView?.title = R.string.localizable
            .onboardingRestoreAccount(preferredLanguages: locale?.rLanguages)

        let text = NSAttributedString(string: R.string.localizable
            .onboardingTermsAndConditions1(preferredLanguages: locale?.rLanguages))
        termsLabel.attributedText = text
    }

    private func adjustLayout() {

        if isAdaptiveHeightDecreased {
            restoreBottomConstraint.constant *= designScaleRatio.height
            termsBottomConstraint.constant *= designScaleRatio.height
        }

        if isAdaptiveWidthDecreased {
            restoreWidthConstraint.constant *= designScaleRatio.width
            signupWidthConstraint.constant *= designScaleRatio.width
        }
    }

    // MARK: Action

    @IBAction private func actionSignup(sender: AnyObject) {
        presenter.activateSignup()
    }

    @IBAction private func actionRestoreAccess(sender: AnyObject) {
        presenter.activateAccountRestore()
    }

    @IBAction private func actionTerms(gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let location = gestureRecognizer.location(in: termsLabel.superview)

            if location.x < termsLabel.center.x {
                presenter.activateTerms()
            } else {
                presenter.activatePrivacy()
            }

        }
    }
}

extension OnboardingMainViewController: OnboardingMainViewProtocol {}
