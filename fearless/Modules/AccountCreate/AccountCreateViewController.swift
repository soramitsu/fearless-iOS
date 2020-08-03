import UIKit
import SoraFoundation
import SoraUI

final class AccountCreateViewController: UIViewController {
    var presenter: AccountCreatePresenterProtocol!

    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var expadableControl: ExpandableActionControl!

    @IBOutlet var networkTypeView: BorderedSubtitleActionView!
    @IBOutlet var cryptoTypeView: BorderedSubtitleActionView!

    @IBOutlet var advancedContainerView: UIView!

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

        configure()

        presenter.setup()
    }

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }

        advancedContainerView.isHidden = !self.expadableControl.isActivated
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

    @IBAction private func actionExpand() {
        stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !expadableControl.isActivated

        if expadableControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
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
