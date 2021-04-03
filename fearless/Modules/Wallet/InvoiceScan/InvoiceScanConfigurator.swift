import Foundation
import CommonWallet
import IrohaCrypto

final class InvoiceScanConfigurator {
    let searchEngine: InvoiceLocalSearchEngineProtocol

    init(networkType: SNAddressType) {
        searchEngine = InvoiceScanLocalSearchEngine(networkType: networkType)
    }

    let style: InvoiceScanViewStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.h3Title, color: R.color.colorWhite()!)
        let message = WalletTextStyle(font: UIFont.h3Title, color: R.color.colorWhite()!)

        let uploadTitle = WalletTextStyle(font: UIFont.h5Title, color: R.color.colorWhite()!)
        let upload = WalletRoundedButtonStyle(background: R.color.colorAccent()!, title: uploadTitle)

        return InvoiceScanViewStyle(
            background: R.color.colorBlack()!,
            title: title,
            message: message,
            maskBackground: R.color.colorBlack()!.withAlphaComponent(0.8),
            upload: upload
        )
    }()

    func configure(builder: InvoiceScanModuleBuilderProtocol) {
        builder
            .with(viewStyle: style)
            .with(localSearchEngine: searchEngine)
    }
}
