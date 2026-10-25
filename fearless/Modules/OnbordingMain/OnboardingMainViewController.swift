import SoraFoundation
import SoraUI
import UIKit

final class OnboardingMainViewController: UIViewController, AdaptiveDesignable {
    var presenter: OnboardingMainPresenterProtocol!
    var welcomeAppearanceEnabled = FWAppearance.welcomeRestyled
    private(set) var welcomeView: FWWelcomeView?

    @IBOutlet private var termsLabel: UILabel!
    @IBOutlet private var signUpButton: TriangularedButton!
    @IBOutlet private var restoreButton: TriangularedButton!
    @IBOutlet private var logoView: UIImageView!
    @IBOutlet var preInstalledButton: TriangularedButton!

    @IBOutlet private var restoreBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var restoreWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var signupWidthConstraint: NSLayoutConstraint!

    @IBOutlet private var termsBottomConstraint: NSLayoutConstraint!

    var termDecorator: AttributedStringDecoratorProtocol?

    // MARK: Appearance

    override func viewDidLoad() {
        super.viewDidLoad()

        if welcomeAppearanceEnabled {
            configureWelcome()
        } else {
            setupLocalization()
            configureLogoView()
            configureTermsLabel()
            adjustLayout()
            preInstalledButton.isHidden = true
            configureLegacyRecoveryAction()
        }
        presenter.setup()
    }

    private func configureLegacyRecoveryAction() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: RecoveryText.string("previous_data"),
            style: .plain,
            target: self,
            action: #selector(showRecoveryData)
        )
    }

    private func configureWelcome() {
        let welcome = FWWelcomeView(mode: .walletChoice)
        welcomeView = welcome
        view = welcome
        welcome.locale = selectedLocale
        welcome.primaryButton.addAction { [weak self] in self?.presenter.activateSignup() }
        welcome.restoreButton.addAction { [weak self] in self?.presenter.activateAccountRestore() }
        welcome.preinstalledButton.addAction { [weak self] in self?.presenter.didTapGetPreinstalled() }
        // Keep the same authenticated route, with a wrapping, scalable target.
        welcome.recoveryButton.addTarget(self, action: #selector(showRecoveryData), for: .touchUpInside)
        welcome.termsButton.addAction { [weak self] in self?.presenter.activateTerms() }
        welcome.privacyButton.addAction { [weak self] in self?.presenter.activatePrivacy() }
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
        preInstalledButton.imageWithTitleView?.title = R.string.localizable.onboardingPreinstalledWalletButtonText(
            preferredLanguages: localizationManager?.selectedLocale.rLanguages
        )
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

    @objc private func showRecoveryData() {
        RetainedDataRestoreRouter.shared.showPreviousData(from: self)
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
        if let welcomeView {
            welcomeView.preinstalledButton.isHidden = !preinstalledWalletEnabled
        } else {
            preInstalledButton.isHidden = !preinstalledWalletEnabled
        }
    }
}

extension OnboardingMainViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }
        if let welcomeView {
            welcomeView.locale = selectedLocale
        } else {
            termDecorator = CompoundAttributedStringDecorator.legal(for: selectedLocale)
            setupLocalization()
            configureTermsLabel()
        }
    }
}
