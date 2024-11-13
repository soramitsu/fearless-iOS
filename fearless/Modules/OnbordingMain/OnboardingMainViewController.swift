import UIKit
import SoraUI
import SoraFoundation

final class OnboardingMainViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = OnboardingMainViewLayout

    var presenter: OnboardingMainPresenterProtocol!

    private let ecosystem: AccountCreateEcosystem?
    private var shouldDismiss: Bool
    init(ecosystem: AccountCreateEcosystem?) {
        self.ecosystem = ecosystem
        self.shouldDismiss = ecosystem != nil
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = OnboardingMainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.setup()
        rootView.preInstalledButton.isHidden = true
        bindActions()
        setupGestureRecognizer()

        if let ecosystem {
            ecosystemHasBeenSelected()
            presenter.didSelect(ecosystem: ecosystem)
        }
    }

    private func bindActions() {
        rootView.selectRegularBannerView.actionButton.addAction { [weak self] in
            guard let self else { return }
            self.presenter.didSelect(ecosystem: .regular)
            self.ecosystemHasBeenSelected()
        }
        rootView.selectTonBannerView.actionButton.addAction { [weak self] in
            guard let self else { return }
            self.presenter.didSelect(ecosystem: .ton)
            self.ecosystemHasBeenSelected()
        }

        rootView.signUpButton.addAction { [weak self] in
            self?.presenter.activateSignup()
        }
        rootView.restoreButton.addAction { [weak self] in
            self?.presenter.activateAccountRestore()
        }
        rootView.preInstalledButton.addAction { [weak self] in
            self?.presenter.didTapGetPreinstalled()
        }
        rootView.backButton.addAction { [weak self] in
            if self?.shouldDismiss == true {
                self?.presenter.dismiss()
            }
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: .curveLinear
            ) { [weak self] in
                self?.rootView.bannerContainer.isHidden = false
                self?.rootView.buttonContainer.alpha = 0
                self?.rootView.bannerContainer.alpha = 1
            } completion: { [weak self] _ in
                self?.rootView.buttonContainer.isHidden = true
                self?.rootView.backButton.isHidden = true
            }
        }
    }

    private func setupGestureRecognizer() {
        let gesture = UITapGestureRecognizer()
        rootView.termsLabel.addGestureRecognizer(gesture)

        gesture.addTarget(self, action: #selector(actionTerms(gestureRecognizer: )))
    }

    private func ecosystemHasBeenSelected() {
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: .curveLinear
        ) { [weak self] in
            self?.rootView.buttonContainer.isHidden = false
            self?.rootView.buttonContainer.alpha = 1
            self?.rootView.bannerContainer.alpha = 0
        } completion: { [weak self] _ in
            self?.rootView.bannerContainer.isHidden = true
            self?.rootView.backButton.isHidden = false
        }
    }

    @objc private func actionTerms(gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let location = gestureRecognizer.location(in: rootView.termsLabel.superview)

            if location.x < rootView.termsLabel.center.x {
                presenter.activateTerms()
            } else {
                presenter.activatePrivacy()
            }
        }
    }
}

extension OnboardingMainViewController: OnboardingMainViewProtocol {
    func didReceive(preinstalledWalletEnabled: Bool) {
        rootView.preInstalledButton.isHidden = !preinstalledWalletEnabled
    }
}

// MARK: - Localizable
extension OnboardingMainViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
