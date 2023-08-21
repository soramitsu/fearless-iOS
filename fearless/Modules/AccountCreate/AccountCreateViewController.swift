import UIKit
import SoraUI
import SoraFoundation
import SnapKit

final class AccountCreateViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountCreateViewLayout

    private let presenter: AccountCreatePresenterProtocol
    private var substrateDerivationPathModel: InputViewModelProtocol?
    private var ethereumDerivationPathModel: InputViewModelProtocol?
    private var isFirstLayoutCompleted: Bool = false

    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    init(presenter: AccountCreatePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AccountCreateViewLayout(flow: presenter.flow)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupLocalization()
        setupActions()

        presenter.setup()
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
}

private extension AccountCreateViewController {
    func setupNavigationItem() {
        let infoItem = UIBarButtonItem(
            image: R.image.iconInfo(),
            style: .plain,
            target: self,
            action: #selector(actionOpenInfo)
        )
        navigationItem.rightBarButtonItem = infoItem
        switch presenter.flow {
        case .wallet, .chain:
            title = R.string.localizable.accountCreateTitle(preferredLanguages: locale.rLanguages)
        case .backup:
            title = R.string.localizable.backupMnemonicTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func setupMnemonicViewIfNeeded() {
        guard rootView.mnemonicView == nil else {
            return
        }

        let mnemonicView = MnemonicDisplayView()

        if let indexColor = R.color.colorGray() {
            mnemonicView.indexTitleColorInColumn = indexColor
        }

        if let titleColor = R.color.colorWhite() {
            mnemonicView.wordTitleColorInColumn = titleColor
        }

        mnemonicView.indexFontInColumn = .p0Digits
        mnemonicView.wordFontInColumn = .p0Paragraph
        mnemonicView.backgroundColor = R.color.colorBlack19()

        rootView.contentView.stackView.insertArrangedSubview(mnemonicView, at: 1)

        rootView.mnemonicView = mnemonicView
    }

    func setupLocalization() {
        rootView.locale = locale
    }

    func setupActions() {
        rootView.nextButton.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
        rootView.substrateDerivationPathField.delegate = self
        rootView.ethereumDerivationPathField.delegate = self

        rootView.substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenCryptoType),
            for: .valueChanged
        )
        rootView.backupButton.addAction { [weak self] in
            self?.presenter.didTapBackupButton()
        }
    }

    private func updateSubstrateDerivationPath(status: FieldStatus) {
        rootView.substrateDerivationPathImage.image = status.icon
    }

    private func updateEthereumDerivationPath(status: FieldStatus) {
        rootView.ethereumDerivationPathImage.image = status.icon
    }

    func viewModel(for field: UITextField) -> InputViewModelProtocol? {
        if field == rootView.substrateDerivationPathField {
            return substrateDerivationPathModel
        } else if field == rootView.ethereumDerivationPathField {
            return ethereumDerivationPathModel
        }
        return nil
    }

    @objc func actionNext() {
        presenter.proceed()
    }

    @objc func actionOpenCryptoType() {
        if rootView.substrateCryptoTypeView.actionControl.isActivated {
            presenter.selectSubstrateCryptoType()
        }
    }

    @objc func actionOpenInfo() {
        presenter.activateInfo()
    }
}

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        setupMnemonicViewIfNeeded()

        rootView.mnemonicView?.bind(words: mnemonic, columnsCount: 2)
    }

    func set(chainType: AccountCreateChainType) {
        rootView.set(chainType: chainType)
    }

    func setSelectedSubstrateCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>) {
        let title = "\(model.underlyingViewModel.title) | \(model.underlyingViewModel.subtitle)"

        rootView.substrateCryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        if model.selectable {
            rootView.substrateCryptoTypeView.enable()
        } else {
            rootView.substrateCryptoTypeView.disable()
        }

        rootView.substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        rootView.substrateCryptoTypeView.actionControl.invalidateLayout()
    }

    func setEthereumCrypto(model: TitleWithSubtitleViewModel) {
        let title = "\(model.title) | \(model.subtitle)"

        rootView.ethereumCryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        rootView.ethereumCryptoTypeView.actionControl.contentView.invalidateLayout()
        rootView.ethereumCryptoTypeView.invalidateLayout()
    }

    func bind(substrateViewModel: InputViewModelProtocol) {
        substrateDerivationPathModel = substrateViewModel

        rootView.substrateDerivationPathField.text = substrateViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.substrateSecretDerivationPath(
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        rootView.substrateDerivationPathField.attributedPlaceholder = attributedPlaceholder

        rootView.substrateDerivationPathLabel.text = R.string.localizable.example(substrateViewModel.placeholder, preferredLanguages: locale.rLanguages)
    }

    func bind(ethereumViewModel: InputViewModelProtocol) {
        ethereumDerivationPathModel = ethereumViewModel

        rootView.ethereumDerivationPathField.text = ethereumViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.ethereumSecretDerivationPath(
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        rootView.ethereumDerivationPathField.attributedPlaceholder = attributedPlaceholder
        rootView.ethereumDerivationPathLabel.text = R.string.localizable.example(ethereumViewModel.placeholder, preferredLanguages: locale.rLanguages)
    }

    func didCompleteCryptoTypeSelection() {
        rootView.substrateCryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didValidateSubstrateDerivationPath(_ status: FieldStatus) {
        updateSubstrateDerivationPath(status: status)
    }

    func didValidateEthereumDerivationPath(_ status: FieldStatus) {
        updateEthereumDerivationPath(status: status)
    }
}

extension AccountCreateViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == rootView.substrateDerivationPathField {
            presenter.validateSubstrate()
        } else if textField == rootView.ethereumDerivationPathField {
            presenter.validateEthereum()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField == rootView.substrateDerivationPathField {
            presenter.validateSubstrate()
        } else if textField == rootView.ethereumDerivationPathField {
            presenter.validateEthereum()
        }
        return false
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = self.viewModel(for: textField) else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension AccountCreateViewController: KeyboardViewAdoptable {
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
                inset.bottom = frame.height + rootView.buttonVStackView.frame.height
                rootView.contentView.scrollView.contentInset = inset
            }
            rootView.contentView.scrollView.scrollRectToVisible(responderFrame, animated: true)
        }
    }
}
