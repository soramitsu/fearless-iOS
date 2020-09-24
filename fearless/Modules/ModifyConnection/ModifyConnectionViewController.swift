import UIKit
import SoraUI
import SoraFoundation

final class ModifyConnectionViewController: UIViewController {
    var presenter: ModifyConnectionPresenterProtocol!

    @IBOutlet private var nameBackgroundView: TriangularedView!
    @IBOutlet private var nameField: AnimatedTextField!
    @IBOutlet private var nodeBackgroundView: TriangularedView!
    @IBOutlet private var nodeField: AnimatedTextField!
    @IBOutlet private var addButton: TriangularedButton!

    private var nameViewModel: InputViewModelProtocol?
    private var nodeViewModel: InputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureFields()
        setupLocalization()
        updateActionButton()

        presenter.setup()
    }

    private func configureFields() {
        nameField.textField.returnKeyType = .done
        nameField.textField.textContentType = .nickname

        nameField.delegate = self

        nodeField.textField.textContentType = .URL
        nodeField.textField.autocapitalizationType = .none
        nodeField.textField.spellCheckingType = .no
        nodeField.textField.autocorrectionType = .no
        nodeField.textField.returnKeyType = .done
        nodeField.textField.keyboardType = .URL

        nodeField.delegate = self
    }

    private func updateActionButton() {
        let isValid = (nameViewModel?.inputHandler.completed ?? false) &&
            (nodeViewModel?.inputHandler.completed ?? false)

        addButton.isEnabled = isValid
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.connectionsAddConnection(preferredLanguages: locale?.rLanguages)
        nameField.title = R.string.localizable.networkInfoName(preferredLanguages: locale?.rLanguages)
        nodeField.title = R.string.localizable.networkInfoAddress(preferredLanguages: locale?.rLanguages)

        addButton.imageWithTitleView?.title = R.string.localizable
            .commonAdd(preferredLanguages: locale?.rLanguages)
        addButton.invalidateLayout()
    }

    @IBAction private func nameFieldDidChange() {
        if nameViewModel?.inputHandler.value != nameField.text {
            nameField.text = nameViewModel?.inputHandler.value
        }

        updateActionButton()
    }

    @IBAction private func nodeFieldDidChange() {
        if nodeViewModel?.inputHandler.value != nodeField.text {
            nodeField.text = nodeViewModel?.inputHandler.value
        }

        updateActionButton()
    }

    @IBAction private func actionAdd() {
        nameField.resignFirstResponder()
        nodeField.resignFirstResponder()

        presenter.add()
    }
}

extension ModifyConnectionViewController: ModifyConnectionViewProtocol {
    func set(nameViewModel: InputViewModelProtocol) {
        self.nameViewModel = nameViewModel

        nameField.text = nameViewModel.inputHandler.value
    }

    func set(nodeViewModel: InputViewModelProtocol) {
        self.nodeViewModel = nodeViewModel

        nodeField.text = nodeViewModel.inputHandler.value
    }
}

extension ModifyConnectionViewController: AnimatedTextFieldDelegate {
    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === nameField {
            viewModel = nameViewModel
        } else {
            viewModel = nodeViewModel
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

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

extension ModifyConnectionViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
