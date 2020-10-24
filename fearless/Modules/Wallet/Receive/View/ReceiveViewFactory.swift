import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class ReceiveViewFactory: ReceiveViewFactoryProtocol {
    let account: AccountItem
    let localizationManager: LocalizationManagerProtocol

    weak var commandFactory: WalletCommandFactoryProtocol?

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(account: AccountItem, localizationManager: LocalizationManagerProtocol) {
        self.account = account
        self.localizationManager = localizationManager
    }

    func createHeaderView() -> UIView? {
        let icon = try? iconGenerator.generateFromAddress(account.address)
            .imageWithFillColor(R.color.colorWhite()!,
                                size: CGSize(width: 32.0, height: 32.0),
                                contentScale: UIScreen.main.scale)

        let receiveView = R.nib.receiveHeaderView(owner: nil)
        receiveView?.accountView.title = account.username
        receiveView?.accountView.subtitle = account.address
        receiveView?.accountView.iconImage = icon
        receiveView?.accountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle

        let locale = localizationManager.selectedLocale
        let alertTitle = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)

        let command = WalletCopyCommand(copyingString: account.address,
                                        alertTitle: alertTitle)
        command.commandFactory = commandFactory
        receiveView?.actionCommand = command

        let infoTitle = R.string.localizable
            .walletReceiveDescription(preferredLanguages: locale.rLanguages)
        receiveView?.infoLabel.text = infoTitle

        return receiveView
    }
}
