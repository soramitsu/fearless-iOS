import Foundation
import CommonWallet
import SoraUI
import SoraFoundation

final class ReceiveConfigurator: AdaptiveDesignable {
    let receiveFactory: ReceiveViewFactory

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            receiveFactory.commandFactory
        }

        set {
            receiveFactory.commandFactory = newValue
        }
    }

    let shareFactory: AccountShareFactoryProtocol

    init(account: AccountItem, assets: [WalletAsset], localizationManager: LocalizationManagerProtocol) {
        receiveFactory = ReceiveViewFactory(account: account,
                                            localizationManager: localizationManager)
        shareFactory = AccountShareFactory(address: account.address,
                                           assets: assets,
                                           localizationManager: localizationManager)
    }

    func configure(builder: ReceiveAmountModuleBuilderProtocol) {
        let margin: CGFloat = 24.0
        let qrSize: CGFloat = 280.0 * designScaleRatio.width + 2.0 * margin
        let style = ReceiveStyle(qrBackgroundColor: .clear,
                                 qrMode: .scaleAspectFit,
                                 qrSize: CGSize(width: qrSize, height: qrSize),
                                 qrMargin: margin)

        let title = LocalizableResource { locale in
            R.string.localizable.walletAssetReceive(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(style: style)
            .with(fieldsInclusion: [])
            .with(title: title)
            .with(viewFactory: receiveFactory)
            .with(accountShareFactory: shareFactory)
    }
}
