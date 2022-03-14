import UIKit
import SoraUI
import SoraFoundation

final class NewAccountCreateViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountCreateViewLayout

    private let presenter: AccountCreatePresenterProtocol
    private var viewModel: InputViewModelProtocol?
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
        view = AccountCreateViewLayout()
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

private extension NewAccountCreateViewController {
    func setupNavigationItem() {
        let infoItem = UIBarButtonItem(
            image: R.image.iconInfo(),
            style: .plain,
            target: self,
            action: #selector(actionOpenInfo)
        )
        navigationItem.rightBarButtonItem = infoItem
        title = R.string.localizable.accountCreateTitle(preferredLanguages: locale.rLanguages)
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
        mnemonicView.backgroundColor = R.color.colorBlack()

        rootView.contentView.stackView.insertArrangedSubview(mnemonicView, at: 1)

        rootView.mnemonicView = mnemonicView
    }

    func setupLocalization() {
        rootView.locale = locale
    }

    func setupActions() {
        rootView.nextButton.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
        rootView.derivationPathField.delegate = self
    }

    func updateDerivationPath(status: FieldStatus) {
        rootView.derivationPathImage.image = status.icon
    }

    @objc func actionNext() {
        presenter.proceed()
    }

    @objc func actionOpenCryptoType() {
        if rootView.cryptoTypeView.actionControl.isActivated {
            presenter.selectSubstrateCryptoType()
        }
    }

    @objc func actionOpenInfo() {
        presenter.activateInfo()
    }
}

extension NewAccountCreateViewController: NewAccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        setupMnemonicViewIfNeeded()

        rootView.mnemonicView?.bind(words: mnemonic, columnsCount: 2)
    }

    func setSelectedCrypto(model: TitleWithSubtitleViewModel) {
        let title = "\(model.title) | \(model.subtitle)"

        rootView.cryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        rootView.cryptoTypeView.actionControl.contentView.invalidateLayout()
        rootView.cryptoTypeView.actionControl.invalidateLayout()
    }

    func bind(viewModel: AccountCreateViewModel) {
        switch viewModel.chainType {
        case .ethereum:
            rootView.derivationPathField.keyboardType = .decimalPad
            rootView.derivationPathLabel.text = R.string.localizable
                .ethereumSecretDerivationPath(preferredLanguages: locale.rLanguages)

            rootView.cryptoTypeView.applyDisabledStyle()
            rootView.cryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
                .ethereumCryptoType(preferredLanguages: locale.rLanguages)
            rootView.cryptoTypeView.actionControl.invalidateLayout()
        case let .substrate(choosable):
            rootView.derivationPathLabel.text = R.string.localizable
                .substrateSecretDerivationPath(preferredLanguages: locale.rLanguages)

            if choosable {
                rootView.cryptoTypeView.actionControl.addTarget(
                    self,
                    action: #selector(actionOpenCryptoType),
                    for: .valueChanged
                )
                rootView.cryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
                    .substrateCryptoType(preferredLanguages: locale.rLanguages)
                rootView.cryptoTypeView.actionControl.invalidateLayout()
            }
        }

        self.viewModel = viewModel
        rootView.derivationPathField.text = viewModel.inputHandler.value
        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.example(
                viewModel.placeholder,
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        rootView.derivationPathField.attributedPlaceholder = attributedPlaceholder
    }

    func didCompleteCryptoTypeSelection() {
        rootView.cryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didValidateDerivationPath(_ status: FieldStatus) {
        updateDerivationPath(status: status)
    }
}

extension NewAccountCreateViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_: UITextField) {
        if let viewModel = viewModel {
            presenter.validateDerivationPath(with: viewModel)
        }
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        resignFirstResponder()
        if let viewModel = viewModel {
            presenter.validateDerivationPath(with: viewModel)
        }
        return false
    }

    func textField(
        _ textField: UITextField,
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
}

extension NewAccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension NewAccountCreateViewController: KeyboardViewAdoptable {
    var targetBottomConstraint: NSLayoutConstraint? { nil }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat {
        if bottomInset > 0.0 {
            return -view.safeAreaInsets.bottom + UIConstants.bigOffset
        } else {
            return UIConstants.bigOffset
        }
    }

    func updateWhileKeyboardFrameChanging(_: CGRect) {
//        rootView.handleKeyboard(frame: frame)
    }
}
