import UIKit
import SoraUI
import SoraFoundation
import FearlessUtils

final class AccountInfoViewController: UIViewController {
    private struct Constants {
        static let bottomContentHeight: CGFloat = 48
    }

    var presenter: AccountInfoPresenterProtocol!

    @IBOutlet private var bottomBarHeight: NSLayoutConstraint!
    @IBOutlet private var addActionControl: IconCellControlView!

    @IBOutlet private var usernameDetailsTextField: AnimatedTextField!

    @IBOutlet private var addressView: DetailsTriangularedView!

    @IBOutlet private var networkView: DetailsTriangularedView!

    @IBOutlet private var cryptoTypeView: DetailsTriangularedView!

    private var usernameViewModel: InputViewModelProtocol?

    private var hasChanges: Bool = false

    var iconGenerating: IconGenerating?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAddressView()
        setupTextField()
        setupLocalization()
        setupNavigationItem()
        updateSaveButton()

        presenter.setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        bottomBarHeight.constant = Constants.bottomContentHeight + view.safeAreaInsets.bottom
    }

    private func setupAddressView() {
        addressView.delegate = self

        addressView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
    }

    private func setupTextField() {
        usernameDetailsTextField.textField.returnKeyType = .done
        usernameDetailsTextField.textField.textContentType = .nickname
        usernameDetailsTextField.textField.autocapitalizationType = .none
        usernameDetailsTextField.textField.autocorrectionType = .no
        usernameDetailsTextField.textField.spellCheckingType = .no

        usernameDetailsTextField.delegate = self
    }

    private func setupNavigationItem() {
        let closeBarItem = UIBarButtonItem(image: R.image.iconClose(),
                                                style: .plain,
                                                target: self,
                                                action: #selector(actionClose))

        navigationItem.leftBarButtonItem = closeBarItem

        let locale = localizationManager?.selectedLocale
        let saveTitle = R.string.localizable
        .commonSave(preferredLanguages: locale?.rLanguages)

        let saveButton = UIBarButtonItem(title: saveTitle,
                                         style: .plain,
                                         target: self,
                                         action: #selector(actionDone))

        saveButton.setupDefaultTitleStyle()

        navigationItem.rightBarButtonItem = saveButton
    }

    private func updateSaveButton() {
        guard
            let rightBarButtonItem = navigationItem.rightBarButtonItem,
            let viewModel = usernameViewModel else {
            return
        }

        rightBarButtonItem.isEnabled = hasChanges && viewModel.inputHandler.completed
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable.accountInfoTitle(preferredLanguages: locale?.rLanguages)

        usernameDetailsTextField.title = R.string.localizable
            .accountInfoNameTitle(preferredLanguages: locale?.rLanguages)

        addActionControl.imageWithTitleView?.title = R.string.localizable
            .commonExport(preferredLanguages: locale?.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonSave(preferredLanguages: locale?.rLanguages)

        addressView.title = R.string.localizable
            .accountInfoTitle(preferredLanguages: locale?.rLanguages)

        cryptoTypeView.title = R.string.localizable
            .commonCryptoType(preferredLanguages: locale?.rLanguages)
    }

    @objc private func actionClose() {
        presenter.activateClose()
    }

    @IBAction private func textFieldDidChange(_ sender: UITextField) {
        hasChanges = true

        if usernameViewModel?.inputHandler.value != sender.text {
            sender.text = usernameViewModel?.inputHandler.value
        }

        updateSaveButton()
    }

    @IBAction private func actionExport() {
        presenter.activateExport()
    }

    @objc private func actionDone() {
        guard let viewModel = usernameViewModel, viewModel.inputHandler.completed else {
            return
        }

        hasChanges = false

        updateSaveButton()

        presenter.save(username: viewModel.inputHandler.value)
    }
}

extension AccountInfoViewController: AnimatedTextFieldDelegate {
    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool {

        guard let viewModel = usernameViewModel else {
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

extension AccountInfoViewController: AccountInfoViewProtocol {
    func set(usernameViewModel: InputViewModelProtocol) {
        usernameDetailsTextField.text = usernameViewModel.inputHandler.value
        self.usernameViewModel = usernameViewModel

        updateSaveButton()
    }

    func set(address: String) {
        addressView.subtitle = address

        addressView.iconImage = try? iconGenerating?
            .generateFromAddress(address)
            .imageWithFillColor(R.color.colorWhite()!,
                                size: UIConstants.smallAddressSize,
                                contentScale: UIScreen.main.scale)
    }

    func set(networkType: Chain) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        networkView.title = networkType.titleForLocale(locale)
        networkView.iconImage = networkType.icon
    }

    func set(cryptoType: CryptoType) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        cryptoTypeView.subtitle = cryptoType.titleForLocale(locale) + " | " + cryptoType.subtitleForLocale(locale)
    }
}

extension AccountInfoViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension AccountInfoViewController: DetailsTriangularedViewDelegate {
    func detailsViewDidSelectAction(_ details: DetailsTriangularedView) {
        presenter.activateAddressAction()
    }
}
