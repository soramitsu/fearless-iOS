import UIKit
import SoraUI
import SoraFoundation

final class NetworkInfoViewController: UIViewController {
    var presenter: NetworkInfoPresenterProtocol!

    @IBOutlet private var nameBackgroundView: TriangularedView!
    @IBOutlet private var nameField: AnimatedTextField!
    @IBOutlet private var nodeBackgroundView: TriangularedView!
    @IBOutlet private var nodeField: AnimatedTextField!

    private var nameViewModel: InputViewModelProtocol?
    private var nodeViewModel: InputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationItem()
        configureFields()

        setupLocalization()

        presenter.setup()
    }

    private func configureFields() {
        nameField.textField.returnKeyType = .done
        nameField.textField.textContentType = .nickname

        nameField.delegate = self

        nodeField.textField.textContentType = .URL
        nodeField.textField.autocapitalizationType = .none
        nodeField.textField.spellCheckingType = .no

        nodeField.delegate = self
    }

    private func configureNavigationItem() {
        let closeBarItem = UIBarButtonItem(image: R.image.iconClose(),
                                                style: .plain,
                                                target: self,
                                                action: #selector(actionClose))

        navigationItem.leftBarButtonItem = closeBarItem
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.networkInfoTitle(preferredLanguages: locale?.rLanguages)
        nameField.title = R.string.localizable.networkInfoName(preferredLanguages: locale?.rLanguages)
        nodeField.title = R.string.localizable.networkInfoAddress(preferredLanguages: locale?.rLanguages)
    }

    @IBAction private func nameFieldDidChange() {
        if nameViewModel?.inputHandler.value != nameField.text {
            nameField.text = nameViewModel?.inputHandler.value
        }
    }

    @IBAction private func nodeFieldDidChange() {
        if nodeViewModel?.inputHandler.value != nodeField.text {
            nodeField.text = nodeViewModel?.inputHandler.value
        }
    }

    @IBAction private func actionNodeCopy() {
        presenter.activateCopy()
    }

    @objc private func actionClose() {
        presenter.activateClose()
    }
}

extension NetworkInfoViewController: NetworkInfoViewProtocol {
    func set(nameViewModel: InputViewModelProtocol) {
        self.nameViewModel = nameViewModel

        nameField.text = nameViewModel.inputHandler.value

        let enabled = nameViewModel.inputHandler.enabled
        nameField.isUserInteractionEnabled = enabled

        if enabled {
            nameBackgroundView.applyEnabledStyle()
        } else {
            nameBackgroundView.applyDisabledStyle()
        }
    }

    func set(nodeViewModel: InputViewModelProtocol) {
        self.nodeViewModel = nodeViewModel

        nodeField.text = nodeViewModel.inputHandler.value

        let enabled = nodeViewModel.inputHandler.enabled
        nodeField.isUserInteractionEnabled = enabled

        if enabled {
            nodeBackgroundView.applyEnabledStyle()
        } else {
            nodeBackgroundView.applyDisabledStyle()
        }
    }
}

extension NetworkInfoViewController: AnimatedTextFieldDelegate {
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

extension NetworkInfoViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
