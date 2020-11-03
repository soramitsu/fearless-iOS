import UIKit
import SoraUI
import SoraFoundation

final class AccountExportPasswordViewController: UIViewController {
    private struct Constants {
        static let bottomOffset: CGFloat = 8.0
    }

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var typeView: BorderedSubtitleActionView!
    @IBOutlet private var hintLabel: UILabel!
    @IBOutlet private var passwordInputField: AnimatedTextField!
    @IBOutlet private var passwordConfirmField: AnimatedTextField!
    @IBOutlet private var actionButton: TriangularedButton!
    @IBOutlet private var contentBottom: NSLayoutConstraint!
    private var errorView: ImageWithTitleView?

    var presenter: AccountExportPasswordPresenterProtocol!

    var keyboardHandler: KeyboardHandler?

    private var passwordInputViewModel: InputViewModelProtocol?
    private var passwordConfirmViewModel: InputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        typeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale?.rLanguages)

        typeView.actionControl.contentView.subtitleLabelView.text = R.string.localizable
            .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale?.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)
    }

    private func setupErrorView() {
        let view = ImageWithTitleView()
        contentView.addSubview(view)

        view.iconImage = R.image.iconError()
        view.titleColor = R.color.colorWhite()
        view.titleFont = UIFont.p2Paragraph

        view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true

        errorView = view
    }

    private func clearErrorView() {
        errorView?.removeFromSuperview()
        errorView = nil
    }

    private func updateBottomConstraint() {
        let offset: CGFloat

        if let errorView = errorView {
            offset = errorView.intrinsicContentSize.height + 2.0 * Constants.bottomOffset
        } else {
            offset = Constants.bottomOffset
        }

        contentBottom.constant = offset
        view.setNeedsLayout()
    }

    private func updateNextButton() {
        let passwordCompleted = passwordInputViewModel?.inputHandler.completed ?? false
        let confirmationCompleted = passwordConfirmViewModel?.inputHandler.completed ?? false

        actionButton.isEnabled = passwordCompleted && confirmationCompleted
    }

    @objc private func actionPasswordInputChange() {
        if passwordInputViewModel?.inputHandler.value != passwordInputField.text {
            passwordInputField.text = passwordInputViewModel?.inputHandler.value
        }

        updateNextButton()

        if errorView != nil {
            clearErrorView()
        }
    }

    @objc private func actionConfirmationInputChange() {
        if passwordConfirmViewModel?.inputHandler.value != passwordConfirmField.text {
            passwordConfirmField.text = passwordConfirmViewModel?.inputHandler.value
        }

        updateNextButton()

        if errorView != nil {
            clearErrorView()
        }
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }
}

extension AccountExportPasswordViewController: AccountExportPasswordViewProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        self.passwordInputViewModel = viewModel
        updateNextButton()
    }

    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) {
        self.passwordConfirmViewModel = viewModel
        updateNextButton()
    }

    func set(error: AccountExportPasswordError) {
        if errorView == nil {
            setupErrorView()
        }

        let content = error.toErrorContent(for: localizationManager?.selectedLocale)
        errorView?.title = content.message
    }
}

extension AccountExportPasswordViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool {
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

            if passwordInputField.isFirstResponder {
                targetView = passwordInputField
            } else if passwordConfirmField.isFirstResponder {
                targetView = passwordConfirmField
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(firstResponderView.frame,
                                                    from: firstResponderView.superview)

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
