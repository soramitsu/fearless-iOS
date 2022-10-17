import UIKit
import SoraFoundation
import SnapKit

final class CreateContactViewController: UIViewController, ViewHolder {
    typealias RootViewType = CreateContactViewLayout

    // MARK: Private properties

    private let output: CreateContactViewOutput
    private var isFirstLayoutCompleted: Bool = false

    // MARK: - Constructor

    init(
        output: CreateContactViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = CreateContactViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        isFirstLayoutCompleted = true
    }

    // MARK: - Private methods

    private func configure() {
        rootView.contactAddressField.textField.delegate = self
        rootView.contactNameField.textField.delegate = self

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )

        rootView.createButton.addTarget(
            self,
            action: #selector(createButtonClicked),
            for: .touchUpInside
        )

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(selectNetworkClicked))
        rootView.selectNetworkView.addGestureRecognizer(tapGesture)
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func createButtonClicked() {
        output.didTapCreateButton()
    }

    @objc private func selectNetworkClicked() {
        output.didTapSelectNetwork()
    }
}

// MARK: - CreateContactViewInput

extension CreateContactViewController: CreateContactViewInput {
    func didReceive(locale: Locale) {
        rootView.locale = locale
    }

    func didReceive(viewModel: CreateContactViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func updateState(isValid: Bool) {
        rootView.updateState(isValid: isValid)
    }
}

// MARK: - Localizable

extension CreateContactViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension CreateContactViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text as NSString? else {
            return true
        }

        let newString = text.replacingCharacters(in: range, with: string)

        if textField == rootView.contactAddressField.textField {
            output.addressTextDidChanged(newString)
        } else if textField == rootView.contactNameField.textField {
            output.nameTextDidChanged(newString)
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField == rootView.contactAddressField.textField {
            output.addressTextDidChanged("")
        } else if textField == rootView.contactNameField.textField {
            output.nameTextDidChanged("")
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else {
            return false
        }

        if textField == rootView.contactAddressField.textField {
            output.addressTextDidChanged(text)
        } else if textField == rootView.contactNameField.textField {
            output.nameTextDidChanged(text)
        }
        return false
    }
}

extension CreateContactViewController: HiddableBarWhenPushed {}

extension CreateContactViewController: KeyboardViewAdoptable {
    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
        UIConstants.bigOffset
    }

    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
