import UIKit
import SoraFoundation
import SoraUI

final class AccountCreateViewController: UIViewController {
    private enum Constants {
        static let nextButtonBottomInset: CGFloat = 16
    }

    var presenter: AccountCreatePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var expadableControl: ExpandableActionControl!
    @IBOutlet private var detailsLabel: UILabel!

    @IBOutlet var substrateCryptoTypeView: BorderedSubtitleActionView!
//    TODO: check replacing to MultilineTriangularedView when switch outlets to layout
    @IBOutlet var ethereumCryptoTypeView: TriangularedTwoLabelView!

    @IBOutlet var substrateDerivationPathLabel: UILabel!
    @IBOutlet var substrateDerivationPathField: UITextField!
    @IBOutlet var substrateDerivationPathImageView: UIImageView!

    @IBOutlet var ethereumDerivationPathImageView: UIImageView!
    @IBOutlet var ethereumDerivationPathField: UITextField!
    @IBOutlet var ethereumDerivationPathLabel: UILabel!

    @IBOutlet var advancedContainerView: UIView!
    @IBOutlet var advancedControl: ExpandableActionControl!

    @IBOutlet var nextButton: TriangularedButton!

    @IBOutlet var nextButtonBottom: NSLayoutConstraint!

    private var substrateDerivationPathModel: InputViewModelProtocol?
    private var ethereumDerivationPathModel: InputViewModelProtocol?
    private var isFirstLayoutCompleted: Bool = false

    private lazy var locale: Locale = {
        localizationManager?.selectedLocale ?? Locale.current
    }()

    var advancedAppearanceAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromBottom,
        curve: .easeOut
    )

    var advancedDismissalAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromTop,
        curve: .easeIn
    )

    private var mnemonicView: MnemonicDisplayView?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupLocalization()
        configure()

        presenter.setup()
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

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }
        ethereumCryptoTypeView.applyDisabledStyle()

        advancedContainerView.isHidden = !expadableControl.isActivated

        substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenCryptoType),
            for: .valueChanged
        )
        ethereumDerivationPathField.keyboardType = .decimalPad
    }

    private func setupNavigationItem() {
        let infoItem = UIBarButtonItem(
            image: R.image.iconInfo(),
            style: .plain,
            target: self,
            action: #selector(actionOpenInfo)
        )
        navigationItem.rightBarButtonItem = infoItem
    }

    private func setupMnemonicViewIfNeeded() {
        guard mnemonicView == nil else {
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

        stackView.insertArrangedSubview(mnemonicView, at: 1)

        self.mnemonicView = mnemonicView
    }

    private func setupLocalization() {
        title = R.string.localizable.accountCreateTitle(preferredLanguages: locale.rLanguages)
        detailsLabel.text = R.string.localizable.accountCreateDetails(preferredLanguages: locale.rLanguages)

        advancedControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)
        advancedControl.invalidateLayout()

        substrateCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .substrateCryptoType(preferredLanguages: locale.rLanguages)
        substrateCryptoTypeView.actionControl.invalidateLayout()
        ethereumCryptoTypeView.twoVerticalLabelView.titleLabel.text = R.string.localizable
            .ethereumCryptoType(preferredLanguages: locale.rLanguages)
        substrateCryptoTypeView.actionControl.invalidateLayout()

        substrateDerivationPathLabel.text = R.string.localizable
            .substrateSecretDerivationPath(preferredLanguages: locale.rLanguages)
        ethereumDerivationPathLabel.text = R.string.localizable
            .ethereumSecretDerivationPath(preferredLanguages: locale.rLanguages)

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()
    }

    private func updateSubstrateDerivationPath(status: FieldStatus) {
        substrateDerivationPathImageView.image = status.icon
    }

    private func updateEthereumDerivationPath(status: FieldStatus) {
        ethereumDerivationPathImageView.image = status.icon
    }

    @IBAction private func actionExpand() {
        stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !expadableControl.isActivated

        if expadableControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            substrateDerivationPathField.resignFirstResponder()
            ethereumDerivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }

    @objc private func actionOpenCryptoType() {
        if substrateCryptoTypeView.actionControl.isActivated {
            presenter.selectSubstrateCryptoType()
        }
    }

    @objc private func actionOpenInfo() {
        presenter.activateInfo()
    }
}

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        setupMnemonicViewIfNeeded()

        mnemonicView?.bind(words: mnemonic, columnsCount: 2)
    }

    func setSelectedSubstrateCrypto(model: TitleWithSubtitleViewModel) {
        let title = "\(model.title) | \(model.subtitle)"

        substrateCryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        substrateCryptoTypeView.actionControl.invalidateLayout()
    }

    func setEthereumCrypto(model: TitleWithSubtitleViewModel) {
        let title = "\(model.title) | \(model.subtitle)"

        ethereumCryptoTypeView.twoVerticalLabelView.subtitleLabelView.text = title

        ethereumCryptoTypeView.twoVerticalLabelView.invalidateLayout()
        ethereumCryptoTypeView.invalidateLayout()
    }

    func bind(substrateViewModel: InputViewModelProtocol) {
        substrateDerivationPathModel = substrateViewModel

        substrateDerivationPathField.text = substrateViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.example(
                substrateViewModel.placeholder,
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        substrateDerivationPathField.attributedPlaceholder = attributedPlaceholder
    }

    func bind(ethereumViewModel: InputViewModelProtocol) {
        ethereumDerivationPathModel = ethereumViewModel

        ethereumDerivationPathField.text = ethereumViewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.example(
                ethereumViewModel.placeholder,
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorGray()!]
        )
        ethereumDerivationPathField.attributedPlaceholder = attributedPlaceholder
    }

    func didCompleteCryptoTypeSelection() {
        substrateCryptoTypeView.actionControl.deactivate(animated: true)
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
        if textField == substrateDerivationPathField {
            presenter.validateSubstrate()
        } else if textField == ethereumDerivationPathField {
            presenter.validateEthereum()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()
        if textField == substrateDerivationPathField {
            presenter.validateSubstrate()
        } else if textField == ethereumDerivationPathField {
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
    var targetBottomConstraint: NSLayoutConstraint? { nextButtonBottom }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat {
        if bottomInset > 0.0 {
            return -view.safeAreaInsets.bottom + Constants.nextButtonBottomInset
        } else {
            return Constants.nextButtonBottomInset
        }
    }
}

private extension AccountCreateViewController {
    func viewModel(for field: UITextField) -> InputViewModelProtocol? {
        if field == substrateDerivationPathField {
            return substrateDerivationPathModel
        } else if field == ethereumDerivationPathField {
            return ethereumDerivationPathModel
        }
        return nil
    }
}
