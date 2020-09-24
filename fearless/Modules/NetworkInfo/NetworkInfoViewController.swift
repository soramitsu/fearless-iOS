import UIKit
import SoraUI
import SoraFoundation

final class NetworkInfoViewController: UIViewController {
    private struct Constants {
        static let margin: CGFloat = 16.0
        static let actionHeight: CGFloat = 52.0
    }

    var presenter: NetworkInfoPresenterProtocol!

    @IBOutlet private var nameBackgroundView: TriangularedView!
    @IBOutlet private var nameField: AnimatedTextField!
    @IBOutlet private var nodeBackgroundView: TriangularedView!
    @IBOutlet private var nodeField: AnimatedTextField!

    private var nameChanged: Bool = false
    private var nodeChanged: Bool = false

    private var actionButton: TriangularedButton?

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
        nodeField.textField.returnKeyType = .done
        nodeField.textField.keyboardType = .URL

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

        actionButton?.imageWithTitleView?.title = R.string.localizable
            .commonUpdate(preferredLanguages: locale?.rLanguages)
        actionButton?.invalidateLayout()
    }

    private func addActionButtonIfNeeded() {
        guard actionButton == nil else {
            return
        }

        let button = TriangularedButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        button.applyDefaultStyle()

        button.imageWithTitleView?.title = R.string.localizable
            .commonUpdate(preferredLanguages: localizationManager?.selectedLocale.rLanguages)

        button.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                        constant: Constants.margin).isActive = true

        button.rightAnchor.constraint(equalTo: view.rightAnchor,
                                      constant: -Constants.margin).isActive = true

        button.topAnchor.constraint(equalTo: nodeBackgroundView.bottomAnchor,
                                      constant: Constants.margin).isActive = true

        button.heightAnchor.constraint(equalToConstant: Constants.actionHeight).isActive = true

        button.addTarget(self,
                         action: #selector(actionUpdate),
                         for: .touchUpInside)

        actionButton = button
    }

    private func clearActionButtonIfNeeded() {
        guard actionButton != nil else {
            return
        }

        actionButton?.removeFromSuperview()
        actionButton = nil
    }

    private func updateActionButton() {
        let isEnabled = (nameViewModel?.inputHandler.completed ?? false) &&
            (nodeViewModel?.inputHandler.completed ?? false) &&
            (nameChanged || nodeChanged)

        actionButton?.isEnabled = isEnabled
    }

    @IBAction private func nameFieldDidChange() {
        if nameViewModel?.inputHandler.value != nameField.text {
            nameField.text = nameViewModel?.inputHandler.value
        }

        nameChanged = true

        updateActionButton()
    }

    @IBAction private func nodeFieldDidChange() {
        if nodeViewModel?.inputHandler.value != nodeField.text {
            nodeField.text = nodeViewModel?.inputHandler.value
        }

        nodeChanged = true

        updateActionButton()
    }

    @IBAction private func actionNodeCopy() {
        presenter.activateCopy()
    }

    @objc private func actionClose() {
        presenter.activateClose()
    }

    @objc private func actionUpdate() {
        presenter.activateUpdate()
    }
}

extension NetworkInfoViewController: NetworkInfoViewProtocol {
    func set(nameViewModel: InputViewModelProtocol) {
        self.nameViewModel = nameViewModel

        nameField.text = nameViewModel.inputHandler.value

        nameChanged = false

        let enabled = nameViewModel.inputHandler.enabled
        nameField.isUserInteractionEnabled = enabled

        if enabled {
            nameBackgroundView.applyEnabledStyle()
        } else {
            nameBackgroundView.applyDisabledStyle()
        }

        let shouldAddAction = (nameViewModel.inputHandler.enabled) || (nodeViewModel?.inputHandler.enabled ?? false)

        if shouldAddAction {
            addActionButtonIfNeeded()
            updateActionButton()
        } else {
            clearActionButtonIfNeeded()
        }
    }

    func set(nodeViewModel: InputViewModelProtocol) {
        self.nodeViewModel = nodeViewModel

        nodeField.text = nodeViewModel.inputHandler.value

        nodeChanged = false

        let enabled = nodeViewModel.inputHandler.enabled
        nodeField.isUserInteractionEnabled = enabled

        if enabled {
            nodeBackgroundView.applyEnabledStyle()
        } else {
            nodeBackgroundView.applyDisabledStyle()
        }

        let shouldAddAction = (nameViewModel?.inputHandler.enabled ?? false) || (nodeViewModel.inputHandler.enabled)

        if shouldAddAction {
            addActionButtonIfNeeded()
            updateActionButton()
        } else {
            clearActionButtonIfNeeded()
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
