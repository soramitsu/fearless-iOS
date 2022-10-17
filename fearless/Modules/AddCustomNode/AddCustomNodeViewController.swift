import UIKit
import SoraUI
import SoraFoundation
import SnapKit

final class AddCustomNodeViewController: UIViewController, ViewHolder {
    typealias RootViewType = AddCustomNodeViewLayout

    let presenter: AddCustomNodePresenterProtocol

    private var nameInputViewModel: InputViewModelProtocol?
    private var urlAddressInputViewModel: InputViewModelProtocol?

    private var isFirstLayoutCompleted: Bool = false

    init(presenter: AddCustomNodePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AddCustomNodeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.nodeNameInputView.animatedInputField.delegate = self
        rootView.nodeAddressInputView.animatedInputField.delegate = self

        rootView.addNodeButton.addTarget(self, action: #selector(addNodeButtonClicked), for: .touchUpInside)
        rootView.navigationBar.backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        isFirstLayoutCompleted = true
    }

    private func updateAddNodeButton() {
        let isEnabled = nameInputViewModel?.inputHandler.completed ?? false
            && urlAddressInputViewModel?.inputHandler.completed ?? false
            && URL(string: urlAddressInputViewModel?.inputHandler.normalizedValue ?? "") != nil
        rootView.addNodeButton.isEnabled = isEnabled
    }

    @objc private func addNodeButtonClicked() {
        rootView.nodeNameInputView.animatedInputField.resignFirstResponder()
        rootView.nodeAddressInputView.animatedInputField.resignFirstResponder()

        presenter.didTapAddNodeButton()
    }

    @objc private func closeButtonClicked() {
        presenter.didTapCloseButton()
    }
}

extension AddCustomNodeViewController: AddCustomNodeViewProtocol {
    func didReceive(locale: Locale) {
        rootView.locale = locale
    }

    func didReceive(nameViewModel: InputViewModelProtocol) {
        nameInputViewModel = nameViewModel

        rootView.nodeNameInputView.animatedInputField.text = nameViewModel.inputHandler.value
        updateAddNodeButton()
    }

    func didReceive(nodeViewModel: InputViewModelProtocol) {
        urlAddressInputViewModel = nodeViewModel

        rootView.nodeAddressInputView.animatedInputField.text = nodeViewModel.inputHandler.value
        updateAddNodeButton()
    }
}

extension AddCustomNodeViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === rootView.nodeNameInputView.animatedInputField {
            viewModel = nameInputViewModel
        } else {
            viewModel = urlAddressInputViewModel
        }

        guard let currentViewModel = viewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }
        updateAddNodeButton()
        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

extension AddCustomNodeViewController: KeyboardViewAdoptable {
    var target: Constraint? { nil }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat {
        if bottomInset > 0.0 {
            return -view.safeAreaInsets.bottom + UIConstants.bigOffset
        } else {
            return UIConstants.bigOffset
        }
    }

    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        rootView.handleKeyboard(frame: frame)
    }
}
