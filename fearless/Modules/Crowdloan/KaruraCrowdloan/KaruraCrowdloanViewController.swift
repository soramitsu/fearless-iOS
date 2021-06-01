import UIKit
import SoraFoundation
import SoraUI

final class KaruraCrowdloanViewController: UIViewController, ViewHolder {
    typealias RootViewType = KaruraCrowdloanViewLayout

    let presenter: KaruraCrowdloanPresenterProtocol

    private var referralViewModel: KaruraReferralViewModel?
    private var codeInputViewModel: InputViewModelProtocol?

    init(presenter: KaruraCrowdloanPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = KaruraCrowdloanViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    private func configure() {
        rootView.codeInputView.animatedInputField.textField.returnKeyType = .done
        rootView.codeInputView.animatedInputField.textField.autocapitalizationType = .none
        rootView.codeInputView.animatedInputField.textField.autocorrectionType = .no
        rootView.codeInputView.animatedInputField.textField.spellCheckingType = .no

        rootView.codeInputView.animatedInputField.delegate = self
        rootView.codeInputView.animatedInputField.addTarget(
            self, action: #selector(actionCodeChanged(_:)),
            for: .editingChanged
        )

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTapTerms(_:)))
        rootView.privacyLabel.addGestureRecognizer(tapGestureRecognizer)

        rootView.signView.addTarget(self, action: #selector(actionSwitchTerms), for: .valueChanged)

        rootView.actionButton.addTarget(self, action: #selector(actionApplyInputCode), for: .touchUpInside)
        rootView.applyAppBonusButton.addTarget(self, action: #selector(actionApplyDefaultCode), for: .touchUpInside)

        rootView.learnMoreView.addTarget(self, action: #selector(actionLearnMore), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable.commonBonus(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale

        applyReferralViewModel()
    }

    private func applyReferralViewModel() {
        guard let referralViewModel = referralViewModel else {
            return
        }

        rootView.applyAppBonusLabel.text = R.string.localizable.crowdloanAppBonusFormat(
            referralViewModel.bonusPercentage,
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.bonusView.valueLabel.text = referralViewModel.bonusValue

        if referralViewModel.canApplyDefaultCode {
            rootView.applyAppBonusButton.imageWithTitleView?.title = R.string.localizable.commonApply(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
        } else {
            rootView.applyAppBonusButton.imageWithTitleView?.title = R.string.localizable.commonApplied(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
        }

        rootView.applyAppBonusButton.invalidateLayout()

        rootView.signView.isOn = referralViewModel.isTermsAgreed

        if !referralViewModel.isCodeReceived {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.karuraReferralCodeAction(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else if !referralViewModel.isTermsAgreed {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.karuraTermsAction(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonApply(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        rootView.actionButton.invalidateLayout()

        rootView.setNeedsLayout()
    }

    @objc private func actionSwitchTerms() {
        presenter.setTermsAgreed(value: rootView.signView.isOn)
    }

    @objc private func actionApplyDefaultCode() {
        presenter.applyDefaultCode()

        rootView.codeInputView.animatedInputField.textField.resignFirstResponder()
    }

    @objc private func actionCodeChanged(_ sender: UITextField) {
        if codeInputViewModel?.inputHandler.value != sender.text {
            sender.text = codeInputViewModel?.inputHandler.value
        }

        presenter.update(referralCode: codeInputViewModel?.inputHandler.value ?? "")
    }

    @objc private func actionApplyInputCode() {
        presenter.applyInputCode()
    }

    @objc private func actionTapTerms(_ sender: UIGestureRecognizer) {
        if sender.state == .ended {
            presenter.presentTerms()
        }
    }

    @objc private func actionLearnMore() {
        presenter.presentLearnMore()
    }
}

extension KaruraCrowdloanViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = codeInputViewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

extension KaruraCrowdloanViewController: KaruraCrowdloanViewProtocol {
    func didReceiveLearnMore(viewModel: LearnMoreViewModel) {
        rootView.learnMoreView.bind(viewModel: viewModel)
    }

    func didReceiveReferral(viewModel: KaruraReferralViewModel) {
        referralViewModel = viewModel

        applyReferralViewModel()
    }

    func didReceiveInput(viewModel: InputViewModelProtocol) {
        codeInputViewModel = viewModel

        rootView.codeInputView.animatedInputField.text = viewModel.inputHandler.value
    }
}

extension KaruraCrowdloanViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
