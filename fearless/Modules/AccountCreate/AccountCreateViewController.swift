import UIKit
import SoraFoundation

final class AccountCreateViewController: UIViewController {
    var presenter: AccountCreatePresenterProtocol!

    @IBOutlet private var stackView: UIStackView!

    private var mnemonicView: MnemonicDisplayView?

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
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

        stackView.addArrangedSubview(mnemonicView)

        self.mnemonicView = mnemonicView
    }
}

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        setupMnemonicViewIfNeeded()

        mnemonicView?.bind(words: mnemonic, columnsCount: 2)
    }

    func setSelectedCrypto(title: String) {

    }

    func setSelectedNetwork(title: String) {

    }

    func setDerivationPath(viewModel: InputViewModelProtocol) {

    }

}
