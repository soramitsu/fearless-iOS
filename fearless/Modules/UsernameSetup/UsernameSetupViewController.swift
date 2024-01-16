import UIKit
import SoraFoundation
import SoraUI
import SnapKit

final class UsernameSetupViewController: UIViewController, ViewHolder {
    enum Constants {
        static let imageSize = CGSize(width: 15, height: 15)
    }

    typealias RootViewType = UsernameSetupViewLayout

    private let presenter: UsernameSetupPresenterProtocol
    private var viewModel: InputViewModelProtocol?
    private var isFirstLayoutCompleted: Bool = false

    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    init(
        presenter: UsernameSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UsernameSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupLocalization()
        setupActions()

        presenter.didLoad(view: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        isFirstLayoutCompleted = true
    }
}

private extension UsernameSetupViewController {
    func setupNavigationItem() {
        title = R.string.localizable.onboardingCreateWallet(preferredLanguages: locale.rLanguages)
    }

    func setupLocalization() {
        rootView.locale = locale
    }

    func setupActions() {
        rootView.nextButton.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
        rootView.usernameTextField.animatedInputField.delegate = self
        rootView.usernameTextField.animatedInputField.addTarget(
            self,
            action: #selector(textFieldDidChange),
            for: .editingChanged
        )
    }

    func updateActionButton() {
        guard let viewModel = viewModel else {
            return
        }

        let isEnabled = viewModel.inputHandler.completed
        rootView.nextButton.set(enabled: isEnabled)
    }

    @objc func actionNext() {
        presenter.proceed()
    }

    @objc func textFieldDidChange(_ sender: UITextField) {
        if viewModel?.inputHandler.value != sender.text {
            sender.text = viewModel?.inputHandler.value
        }

        updateActionButton()
    }
}

extension UsernameSetupViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = viewModel else {
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

extension UsernameSetupViewController: UsernameSetupViewProtocol {
    func bindUsername(viewModel: SelectableViewModel<InputViewModelProtocol>) {
        self.viewModel = viewModel.underlyingViewModel
        rootView.usernameTextField.text = viewModel.underlyingViewModel.inputHandler.value
        rootView.usernameTextFieldContainer.isHidden = !viewModel.selectable
        rootView.hintLabelContainer.isHidden = !viewModel.selectable
        updateActionButton()

        if viewModel.selectable {
            rootView.usernameTextField.animatedInputField.textField.becomeFirstResponder()
        }
    }

    func bindUniqueChain(viewModel: UniqueChainViewModel) {
        rootView.chainViewContainer.isHidden = false
        rootView.chainView.actionControl.contentView.subtitleLabelView.text = viewModel.text
        let imageView = rootView.chainView.actionControl.contentView.subtitleImageView
        viewModel.icon?.loadImage(
            on: imageView,
            targetSize: Constants.imageSize,
            animated: true
        )
    }
}

extension UsernameSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension UsernameSetupViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        if let responder = rootView.firstResponder {
            var inset = rootView.contentView.scrollView.contentInset
            var responderFrame: CGRect
            responderFrame = responder.convert(responder.frame, to: rootView.contentView.scrollView)

            if frame.height == 0 {
                inset.bottom = 0
                rootView.contentView.scrollView.contentInset = inset
            } else {
                inset.bottom = frame.height
                rootView.contentView.scrollView.contentInset = inset
            }
            rootView.contentView.scrollView.scrollRectToVisible(responderFrame, animated: true)
        }
    }
}
