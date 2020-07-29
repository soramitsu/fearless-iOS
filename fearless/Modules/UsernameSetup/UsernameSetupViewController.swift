import UIKit
import SoraFoundation
import SoraUI

final class UsernameSetupViewController: UIViewController {
    var presenter: UsernameSetupPresenterProtocol!

    @IBOutlet private var inputField: UITextField!
    @IBOutlet private var hintLabel: UILabel!
    @IBOutlet private var nextButton: TriangularedButton!

    @IBOutlet private var nextBottom: NSLayoutConstraint!

    private var isFirstLayoutCompleted: Bool = false

    private var viewModel: InputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()

            inputField.becomeFirstResponder()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        guard !isFirstLayoutCompleted else {
            return
        }

        isFirstLayoutCompleted = true

        if currentKeyboardFrame != nil {
            applyCurrentKeyboardFrame()
        }

        super.viewDidLayoutSubviews()
    }

    private func updateActionButton() {
        guard let viewModel = viewModel else {
            return
        }

        nextButton.isEnabled = viewModel.inputHandler.completed
    }

    // MARK: Private

    @IBAction private func textFieldDidChange(_ sender: UITextField) {
        if viewModel?.inputHandler.value != sender.text {
            sender.text = viewModel?.inputHandler.value
        }

        updateActionButton()
    }
}

extension UsernameSetupViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        guard let viewModel = viewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

extension UsernameSetupViewController: KeyboardViewAdoptable {
    var targetBottomConstraint: NSLayoutConstraint? { nextBottom }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat {
        -view.safeAreaInsets.bottom + 24
    }
}

extension UsernameSetupViewController: UsernameSetupViewProtocol {
    func set(viewModel: InputViewModelProtocol) {
        self.viewModel = viewModel

        updateActionButton()
    }
}

extension UsernameSetupViewController: Localizable {
    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations

        title = R.string.localizable.onboardingCreateAccount(preferredLanguages: languages)

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: languages)
        nextButton.invalidateLayout()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
