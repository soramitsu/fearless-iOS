import Foundation
import CommonWallet
import SoraFoundation

struct AmountFormatterFactory: NumberFormatterFactoryProtocol {
    func createInputFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        return createFormatter(for: asset)
    }

    func createDisplayFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        return createFormatter(for: asset)
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenAmountFormatter> {
        let numberFormatter = createNumberFormatter(for: asset)

        return TokenAmountFormatter(numberFormatter: numberFormatter,
                                    tokenSymbol: asset?.symbol ?? "",
                                    separator: " ",
                                    position: .suffix).localizableResource()
    }

    private func createFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        createNumberFormatter(for: asset).localizableResource()
    }

    private func createNumberFormatter(for asset: WalletAsset?) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        if let asset = asset {
            formatter.maximumFractionDigits = Int(asset.precision)
        }

        return formatter
    }
}
