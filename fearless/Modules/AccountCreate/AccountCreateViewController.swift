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

    let stackViewAnimator = TransitionAnimator(type: .reveal)

    private var mnemonicView: MnemonicDisplayView?

    override func viewDidLoad() {
        super.viewDidLoad()

        advancedContainerView.isHidden = !self.expadableControl.isActivated

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

        stackView.insertArrangedSubview(mnemonicView, at: 1)

        self.mnemonicView = mnemonicView
    }

    @IBAction private func actionExpand() {
        stackView.subviews.forEach { view in
            view.backgroundColor = R.color.colorBlack()
        }

        stackView.sendSubviewToBack(advancedContainerView)

        CATransaction.begin()

        let animation = CATransition()
        animation.type = .push

        if expadableControl.isActivated {
            animation.subtype = .fromBottom
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        } else {
            animation.subtype = .fromTop
            animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        }

        animation.duration = 0.35
        advancedContainerView.layer.add(animation, forKey: nil)

        advancedContainerView.isHidden = !expadableControl.isActivated

        CATransaction.commit()
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
