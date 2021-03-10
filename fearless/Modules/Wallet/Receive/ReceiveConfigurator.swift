import Foundation
import CommonWallet
import SoraUI
import SoraFoundation
import SoraKeystore

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

    init(settings: SettingsManagerProtocol,
         assets: [WalletAsset],
         localizationManager: LocalizationManagerProtocol) {
        let accountViewModel = ReceiveAccountViewModel(settings: settings)
        let chain = settings.selectedConnection.type.chain

        receiveFactory = ReceiveViewFactory(accountViewModel: accountViewModel,
                                            chain: chain,
                                            localizationManager: localizationManager)
        shareFactory = AccountShareFactory(accountViewModel: accountViewModel,
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
