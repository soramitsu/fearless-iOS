import UIKit
import SoraUI

final class OnboardingMainViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    private struct Constants {
        static let restoreBottomFriction: CGFloat = 0.9
        static let signupBottomFriction: CGFloat = 0.9
    }

    var presenter: OnboardingMainPresenterProtocol!

    @IBOutlet private var termsLabel: UILabel!
    @IBOutlet private var signUpButton: RoundedButton!
    @IBOutlet private var restoreButton: RoundedButton!
    @IBOutlet private var logoView: UIImageView!

    @IBOutlet private var restoreBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var signupBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var termsBottomConstraint: NSLayoutConstraint!

    var locale: Locale?

    var termDecorator: AttributedStringDecoratorProtocol?

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

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
        logoView.tintColor = .iconTintColor
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
            signupBottomConstraint.constant *= designScaleRatio.height
        }

        if isAdaptiveHeightIncreased {
            restoreBottomConstraint.constant *= designScaleRatio.height * Constants.restoreBottomFriction
            signupBottomConstraint.constant *= designScaleRatio.height * Constants.signupBottomFriction
        }

        termsBottomConstraint.constant *= designScaleRatio.height
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
