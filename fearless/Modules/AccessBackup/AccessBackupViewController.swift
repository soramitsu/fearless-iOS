import UIKit
import SoraUI
import SoraFoundation

final class AccessBackupViewController: AccessoryViewController {
    enum Mode {
        case registration
        case view
    }

    var presenter: AccessBackupPresenterProtocol!

    @IBOutlet private var phraseLabel: UILabel!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var phraseHeaderLabel: UILabel!

    var mode: Mode = .registration

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()

        shouldSetupKeyboardHandler = false

        configurePhraseLabel()

        presenter.setup()
    }

    private func configurePhraseLabel() {
        phraseLabel.text = ""
    }

    // MARK: Accessory View Controller

    override func setupLocalization() {
        super.setupLocalization()

        let languages = localizationManager?.preferredLocalizations

        title = R.string.localizable
            .commonPassphraseTitle(preferredLanguages: languages)
        titleLabel.text = R.string.localizable
            .commonPassphraseHeader(preferredLanguages: languages)
        subtitleLabel.text = R.string.localizable
            .commonPassphraseBody(preferredLanguages: languages)
        phraseHeaderLabel.text = R.string.localizable
            .commonPassphraseYourPassphrase(preferredLanguages: languages)
    }

    override func configureAccessoryView() {
        if mode == .registration {
            super.configureAccessoryView()
        }
    }

    override func actionAccessory() {
        presenter.activateNext()
    }
}

extension AccessBackupViewController: AccessBackupViewProtocol {
    func didReceiveBackup(mnemonic: String) {
        phraseLabel.text = mnemonic
    }
}
