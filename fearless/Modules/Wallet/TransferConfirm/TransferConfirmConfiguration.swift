import Foundation
import CommonWallet
import SoraFoundation

final class TransferConfirmConfigurator {
    func configure(builder: TransferConfirmationModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable.walletSendConfirmTitle(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(localizableTitle: title)
            .with(accessoryViewType: .onlyActionBar)
            .with(completion: .hide)
    }
}
