import UIKit
import SoraUI
import SoraFoundation

final class AccessRestoreViewController: AccessoryViewController {
    var presenter: AccessRestorePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var roundedView: RoundedView!
    @IBOutlet private var phraseTextView: UITextView!
    @IBOutlet private var phrasePlaceholder: UILabel!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private var model: InputViewModelProtocol? {
        didSet {
            phraseTextView.text = model?.inputHandler.value

            updatePlaceholder()
            updateNextButton()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTextView()
        updatePlaceholder()
        updateNextButton()

        presenter.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        phraseTextView.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        phraseTextView.resignFirstResponder()
    }

    private func configureTextView() {
        phraseTextView.tintColor = R.color.colorWhite()!
    }

    // MARK: Accessory Override

    override func setupLocalization() {
        super.setupLocalization()

        let languages = localizationManager?.preferredLocalizations

        title = R.string.localizable.recoveryTitle(preferredLanguages: languages)

        titleLabel.text = R.string.localizable.recoveryBodyTitle(preferredLanguages: languages)
        subtitleLabel.text = R.string.localizable.recoveryBodySubtitle(preferredLanguages: languages)
        phrasePlaceholder.text = R.string.localizable.recoveryPassphrase(preferredLanguages: languages)
    }

    override func updateBottom(inset: CGFloat) {
        super.updateBottom(inset: inset)

        var contentInset = scrollView.contentInset
        contentInset.bottom = inset
        scrollView.contentInset = contentInset
    }

    override func actionAccessory() {
        super.actionAccessory()

        phraseTextView.resignFirstResponder()
        presenter.activateAccessRestoration()
    }

    // MARK: Text View

    private func updateNextButton() {
        accessoryView?.isActionEnabled = phraseTextView.text.count > 0
    }

    private func updatePlaceholder() {
        phrasePlaceholder.isHidden = phraseTextView.text.count > 0
    }
}

extension AccessRestoreViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView.text != model?.inputHandler.value {
            textView.text = model?.inputHandler.value
        }

        updatePlaceholder()
        updateNextButton()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text.rangeOfCharacter(from: CharacterSet.newlines) != nil {
            phraseTextView.resignFirstResponder()
            presenter.activateAccessRestoration()
            return false
        }

        guard let model = model else {
            return false
        }

        let shouldApply = model.inputHandler.didReceiveReplacement(text, for: range)

        if !shouldApply, textView.text != model.inputHandler.value {
            textView.text = model.inputHandler.value
        }

        return shouldApply
    }
}

extension AccessRestoreViewController: AccessRestoreViewProtocol {
    func didReceiveView(model: InputViewModelProtocol) {
        self.model = model
    }
}
