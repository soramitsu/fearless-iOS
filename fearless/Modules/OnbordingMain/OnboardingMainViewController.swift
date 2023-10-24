import UIKit
import SoraUI
import SoraFoundation

final class OnboardingMainViewController: UIViewController, AdaptiveDesignable {
    var presenter: OnboardingMainPresenterProtocol!

    @IBOutlet private var termsLabel: UILabel!
    @IBOutlet private var signUpButton: TriangularedButton!
    @IBOutlet private var restoreButton: TriangularedButton!
    @IBOutlet private var logoView: UIImageView!
    @IBOutlet var preInstalledButton: TriangularedButton!

    @IBOutlet private var restoreBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var restoreWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var signupWidthConstraint: NSLayoutConstraint!

    @IBOutlet private var termsBottomConstraint: NSLayoutConstraint!

    var localizationManager: LocalizationManagerProtocol?

    var termDecorator: AttributedStringDecoratorProtocol?

    // MARK: Appearance

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureLogoView()
        configureTermsLabel()
        adjustLayout()

        presenter.setup()

        preInstalledButton.isHidden = true
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
            .usernameSetupTitle20(preferredLanguages: localizationManager?.selectedLocale.rLanguages)
        restoreButton.imageWithTitleView?.title = R.string.localizable
            .onboardingRestoreWallet(preferredLanguages: localizationManager?.selectedLocale.rLanguages)
        preInstalledButton.imageWithTitleView?.title = R.string.localizable.onboardingPreinstalledWalletButtonText(preferredLanguages: localizationManager?.selectedLocale.rLanguages)
        preInstalledButton.imageWithTitleView?.iconImage = R.image.iconPreinstalledWallet()
        let text = NSAttributedString(string: R.string.localizable
            .onboardingTermsAndConditions1(preferredLanguages: localizationManager?.selectedLocale.rLanguages))
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

    @IBAction private func actionSignup(sender _: AnyObject) {
        presenter.activateSignup()
    }

    @IBAction private func actionRestoreAccess(sender _: AnyObject) {
        presenter.activateAccountRestore()
    }

    @IBAction func actionPreinstalled() {
        presenter.didTapGetPreinstalled()
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

extension OnboardingMainViewController: OnboardingMainViewProtocol {
    func didReceive(preinstalledWalletEnabled: Bool) {
        preInstalledButton.isHidden = !preinstalledWalletEnabled
    }
}
