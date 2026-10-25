import UIKit
import SoraUI
import SoraFoundation

final class AccountExportPasswordViewController: UIViewController, ImportantViewProtocol {
    private let errorBottomOffset: CGFloat = 8.0

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var typeView: BorderedSubtitleActionView!
    @IBOutlet private var hintLabel: UILabel!
    @IBOutlet private var passwordInputField: AnimatedTextField!
    @IBOutlet private var passwordConfirmField: AnimatedTextField!
    @IBOutlet private var actionButton: TriangularedButton!
    @IBOutlet private var contentBottom: NSLayoutConstraint!
    @IBOutlet private var passwordInputEye: RoundedButton!
    @IBOutlet private var passwordConfirmEye: RoundedButton!
    private var errorView: ImageWithTitleView?
    private var isExporting = false
    private var displayedError: AccountExportPasswordError?
    private var adaptiveLayout: AccountExportPasswordAdaptiveLayout?

    var presenter: AccountExportPasswordPresenterProtocol!

    var keyboardHandler: FearlessKeyboardHandler?

    private var passwordInputViewModel: InputViewModelProtocol?
    private var passwordConfirmViewModel: InputViewModelProtocol?

    var inputCompleted: Bool {
        let passwordCompleted = passwordInputViewModel?.inputHandler.completed ?? false
        let confirmationCompleted = passwordConfirmViewModel?.inputHandler.completed ?? false

        return passwordCompleted && confirmationCompleted
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTextFields()
        setupAdaptiveLayout()

        updateNextButton()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presenter.didAppearView()
    }

    override func willMove(toParent parent: UIViewController?) {
        if parent == nil, isViewLoaded { presenter.willLeaveView() }
        super.willMove(toParent: parent)
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil, isViewLoaded { presenter.didLeaveView() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            presenter.willLeaveView()
            if let transitionCoordinator {
                transitionCoordinator.animate(alongsideTransition: nil) { [weak self] context in
                    self?.presenter.didFinishLeavingView(cancelled: context.isCancelled)
                }
            } else { presenter.didLeaveView() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            if adaptiveLayout != nil {
                keyboardHandler = FearlessKeyboardHandler(with: self)
            } else {
                setupKeyboardHandler()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard isViewLoaded,
              previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
              previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight else { return }
        refreshAdaptivePresentation()
    }

    private func setupAdaptiveLayout() {
        guard FWAppearance.accountExportPasswordRestyled,
              let password = passwordInputField as? AccountExportPasswordField,
              let confirmation = passwordConfirmField as? AccountExportPasswordField else { return }
        adaptiveLayout = AccountExportPasswordAdaptiveLayout(
            root: view, scroll: scrollView, content: contentView, source: typeView, hint: hintLabel,
            fields: [password, confirmation], action: actionButton, contentBottom: contentBottom
        )
        navigationItem.titleView = UIView()
        refreshAdaptivePresentation()
    }

    private func refreshAdaptivePresentation() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        adaptiveLayout?.refresh(
            title: title,
            source: typeView,
            action: actionButton,
            locale: locale,
            traits: traitCollection
        )
        adaptiveLayout?.setError(displayedError?.toErrorContent(for: locale).message)
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        switch presenter.flow {
        case .multiple:
            title = R.string.localizable.exportWallet(preferredLanguages: locale?.rLanguages)
        case .single:
            title = R.string.localizable.commonExport(preferredLanguages: locale?.rLanguages)
        }

        hintLabel.text = R.string.localizable.accountExportJsonHint(preferredLanguages: locale?.rLanguages)

        typeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale?.rLanguages)

        typeView.actionControl.contentView.subtitleLabelView.text = R.string.localizable
            .importRecoveryJson(preferredLanguages: locale?.rLanguages)

        passwordInputField.title = R.string.localizable
            .commonSetPassword(preferredLanguages: locale?.rLanguages)

        passwordConfirmField.title = R.string.localizable
            .commonConfirmPassword(preferredLanguages: locale?.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale?.rLanguages)
        refreshAdaptivePresentation()
    }

    private func setupTextFields() {
        passwordInputField.textField.isSecureTextEntry = true
        passwordInputField.textField.returnKeyType = .done
        passwordInputField.delegate = self
        passwordInputField.addTarget(
            self,
            action: #selector(actionPasswordInputChange),
            for: .editingChanged
        )

        passwordConfirmField.textField.isSecureTextEntry = true
        passwordConfirmField.textField.returnKeyType = .done
        passwordConfirmField.delegate = self
        passwordConfirmField.addTarget(
            self,
            action: #selector(actionConfirmationInputChange),
            for: .editingChanged
        )
    }

    private func setupErrorView() {
        let view = ImageWithTitleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)

        view.iconImage = R.image.iconError()
        view.titleColor = R.color.colorWhite()
        view.titleFont = UIFont.p2Paragraph

        view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        view.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -errorBottomOffset
        ).isActive = true

        errorView = view

        updateBottomConstraint()
    }

    private func clearErrorView() {
        displayedError = nil
        adaptiveLayout?.setError(nil)
        errorView?.removeFromSuperview()
        errorView = nil
    }

    private func updateBottomConstraint() {
        let offset: CGFloat

        if let errorView = errorView {
            offset = errorView.intrinsicContentSize.height + 2.0 * errorBottomOffset
        } else {
            offset = errorBottomOffset
        }

        contentBottom.constant = offset
        view.setNeedsLayout()
    }

    private func updateNextButton() {
        actionButton.set(enabled: inputCompleted && !isExporting)
    }

    private func toggleSecurity(_ textField: UITextField, eyeButton: RoundedButton) {
        let isSecure = !textField.isSecureTextEntry

        if isSecure {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconEye()
        } else {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconNoEye()
        }

        textField.isSecureTextEntry = isSecure
    }

    @objc private func actionPasswordInputChange() {
        if passwordInputViewModel?.inputHandler.value != passwordInputField.text {
            passwordInputField.text = passwordInputViewModel?.inputHandler.value
        }

        updateNextButton()

        if errorView != nil || displayedError != nil {
            clearErrorView()
        }
    }

    @objc private func actionConfirmationInputChange() {
        if passwordConfirmViewModel?.inputHandler.value != passwordConfirmField.text {
            passwordConfirmField.text = passwordConfirmViewModel?.inputHandler.value
        }

        updateNextButton()

        if errorView != nil || displayedError != nil {
            clearErrorView()
        }
    }

    @IBAction private func actionPasswordInputEyeToggle() {
        toggleSecurity(passwordInputField.textField, eyeButton: passwordInputEye)
    }

    @IBAction private func actionPasswordConfirmEyeToggle() {
        toggleSecurity(passwordConfirmField.textField, eyeButton: passwordConfirmEye)
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }
}

extension AccountExportPasswordViewController: AccountExportPasswordViewProtocol {
    func setExporting(_ exporting: Bool) {
        isExporting = exporting
        updateNextButton()
    }

    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        passwordInputViewModel = viewModel
        updateNextButton()
    }

    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) {
        passwordConfirmViewModel = viewModel
        updateNextButton()
    }

    func set(error: AccountExportPasswordError) {
        displayedError = error
        if let adaptiveLayout {
            adaptiveLayout.setError(error.toErrorContent(for: localizationManager?.selectedLocale).message)
            return
        }
        if errorView == nil {
            setupErrorView()
        }

        let content = error.toErrorContent(for: localizationManager?.selectedLocale)
        errorView?.title = content.message
    }
}

extension AccountExportPasswordViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        if textField === passwordInputField, passwordConfirmViewModel?.inputHandler.value.isEmpty == true {
            passwordConfirmField.becomeFirstResponder()
        } else if textField === passwordConfirmField, inputCompleted {
            textField.resignFirstResponder()

            presenter.proceed()
        } else {
            textField.resignFirstResponder()
        }

        return false
    }

    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === passwordInputField {
            viewModel = passwordInputViewModel
        } else {
            viewModel = passwordConfirmViewModel
        }

        guard let currentViewModel = viewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountExportPasswordViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if adaptiveLayout != nil, passwordInputField.textField.isFirstResponder {
                targetView = passwordInputField.textField
            } else if adaptiveLayout != nil, passwordConfirmField.textField.isFirstResponder {
                targetView = passwordConfirmField.textField
            } else if passwordInputField.isFirstResponder {
                targetView = passwordInputField
            } else if passwordConfirmField.isFirstResponder {
                targetView = passwordConfirmField
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

extension AccountExportPasswordViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension AccountExportPasswordViewController: KeyboardHandlerDelegate {
    func keyboardWillShow(notification: Notification) {
        keyboardWillChangeFrame(notification: notification)
    }

    func keyboardWillHide(notification: Notification) {
        keyboardWillChangeFrame(notification: notification)
    }

    func keyboardWillChangeFrame(notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        updateWhileKeyboardFrameChanging(frame.cgRectValue)
    }
}
