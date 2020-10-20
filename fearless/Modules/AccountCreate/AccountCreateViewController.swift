import UIKit
import SoraFoundation
import SoraUI

final class AccountCreateViewController: UIViewController {
    var presenter: AccountCreatePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var expadableControl: ExpandableActionControl!
    @IBOutlet private var detailsLabel: UILabel!

    @IBOutlet var networkTypeView: BorderedSubtitleActionView!
    @IBOutlet var cryptoTypeView: BorderedSubtitleActionView!

    @IBOutlet var derivationPathView: UIView!
    @IBOutlet var derivationPathLabel: UILabel!
    @IBOutlet var derivationPathField: UITextField!
    @IBOutlet var derivationPathImageView: UIImageView!

    @IBOutlet var advancedContainerView: UIView!
    @IBOutlet var advancedControl: ExpandableActionControl!

    @IBOutlet var nextButton: TriangularedButton!

    private var derivationPathModel: InputViewModelProtocol?

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(type: .push,
                                                        duration: 0.35,
                                                        subtype: .fromBottom,
                                                        curve: .easeOut)

    var advancedDismissalAnimator = TransitionAnimator(type: .push,
                                                       duration: 0.35,
                                                       subtype: .fromTop,
                                                       curve: .easeIn)

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

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }

        advancedContainerView.isHidden = !expadableControl.isActivated

        cryptoTypeView.actionControl.addTarget(self,
                                               action: #selector(actionOpenCryptoType),
                                               for: .valueChanged)

        networkTypeView.actionControl.addTarget(self,
                                                action: #selector(actionOpenNetworkType),
                                                for: .valueChanged)
    }

    private func setupNavigationItem() {
        let infoItem = UIBarButtonItem(image: R.image.iconInfo(),
                                       style: .plain,
                                       target: self,
                                       action: #selector(actionOpenInfo))
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
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.accountCreateTitle(preferredLanguages: locale.rLanguages)
        detailsLabel.text = R.string.localizable.accountCreateDetails(preferredLanguages: locale.rLanguages)

        advancedControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)
        advancedControl.invalidateLayout()

        cryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonCryptoType(preferredLanguages: locale.rLanguages)
        cryptoTypeView.actionControl.invalidateLayout()

        derivationPathLabel.text = R.string.localizable
            .commonSecretDerivationPath(preferredLanguages: locale.rLanguages)

        networkTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonChooseNetwork(preferredLanguages: locale.rLanguages)
        networkTypeView.invalidateLayout()

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()
    }

    private func updateDerivationPath(status: FieldStatus) {
        derivationPathImageView.image = status.icon
    }

    @IBAction private func actionExpand() {
        stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !expadableControl.isActivated

        if expadableControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            derivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }

    @IBAction private func actionTextFieldEditingChanged() {
        if derivationPathModel?.inputHandler.value != derivationPathField.text {
            derivationPathField.text = derivationPathModel?.inputHandler.value
        }
    }

    @objc private func actionOpenCryptoType() {
        if cryptoTypeView.actionControl.isActivated {
            presenter.selectCryptoType()
        }
    }

    @objc private func actionOpenNetworkType() {
        if networkTypeView.actionControl.isActivated {
            presenter.selectNetworkType()
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

    func setSelectedCrypto(model: TitleWithSubtitleViewModel) {
        let title = "\(model.title) | \(model.subtitle)"

        cryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        cryptoTypeView.actionControl.contentView.invalidateLayout()
        cryptoTypeView.actionControl.invalidateLayout()
    }

    func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>) {
        networkTypeView.actionControl.contentView.subtitleImageView.image = model.underlyingViewModel.icon
        networkTypeView.actionControl.contentView.subtitleLabelView.text = model.underlyingViewModel.title

        networkTypeView.actionControl.showsImageIndicator = model.selectable
        networkTypeView.isUserInteractionEnabled = model.selectable
        networkTypeView.fillColor = model.selectable ? .clear : R.color.colorDarkGray()!
        networkTypeView.strokeColor = model.selectable ? R.color.colorGray()! : .clear

        networkTypeView.actionControl.contentView.invalidateLayout()
        networkTypeView.actionControl.invalidateLayout()
    }

    func setDerivationPath(viewModel: InputViewModelProtocol) {
        derivationPathModel = viewModel

        derivationPathField.text = viewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(string: viewModel.placeholder,
                                                       attributes: [.foregroundColor: R.color.colorGray()!])
        derivationPathField.attributedPlaceholder = attributedPlaceholder
    }

    func didCompleteCryptoTypeSelection() {
        cryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didCompleteNetworkTypeSelection() {
        networkTypeView.actionControl.deactivate(animated: true)
    }

    func didValidateDerivationPath(_ status: FieldStatus) {
        updateDerivationPath(status: status)
    }
}

extension AccountCreateViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        presenter.validate()

        return false
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        guard let viewModel = derivationPathModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountCreateViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let fieldFrame = scrollView.convert(networkTypeView.frame,
                                                from: networkTypeView.superview)

            scrollView.scrollRectToVisible(fieldFrame, animated: true)
        }
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
