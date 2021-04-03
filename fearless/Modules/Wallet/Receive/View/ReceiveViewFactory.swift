import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils
import SoraKeystore

final class ReceiveViewFactory: ReceiveViewFactoryProtocol {
    let accountViewModel: ReceiveAccountViewModelProtocol
    let chain: Chain
    let localizationManager: LocalizationManagerProtocol

    weak var commandFactory: WalletCommandFactoryProtocol?

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        accountViewModel: ReceiveAccountViewModelProtocol,
        chain: Chain,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.accountViewModel = accountViewModel
        self.chain = chain
        self.localizationManager = localizationManager
    }

    func createHeaderView() -> UIView? {
        let address = accountViewModel.address
        let username = accountViewModel.displayName

        let icon = try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: CGSize(width: 32.0, height: 32.0),
                contentScale: UIScreen.main.scale
            )

        let receiveView = R.nib.receiveHeaderView(owner: nil)
        receiveView?.accountView.title = username
        receiveView?.accountView.subtitle = address
        receiveView?.accountView.iconImage = icon
        receiveView?.accountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle

        let locale = localizationManager.selectedLocale

        if let commandFactory = commandFactory {
            let command = WalletAccountOpenCommand(
                address: address,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
            receiveView?.actionCommand = command
        }

        let infoTitle = R.string.localizable
            .walletReceiveDescription(preferredLanguages: locale.rLanguages)
        receiveView?.infoLabel.text = infoTitle

        return receiveView
    }
}
