import Foundation
import CommonWallet
import SoraFoundation

struct AmountFormatterFactory: NumberFormatterFactoryProtocol {
    let assetPrecision: Int
    let usdPrecision: Int

    init(assetPrecision: Int = 4,
         usdPrecision: Int = 2) {
        self.assetPrecision = assetPrecision
        self.usdPrecision = usdPrecision
    }

    func createInputFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        if let asset = asset {
            formatter.maximumFractionDigits = Int(asset.precision)
        }

        return formatter.localizableResource()
    }

    func createDisplayFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        if asset?.identifier == WalletAssetId.usd.rawValue {
            return createFormatter(for: usdPrecision)
        } else {
            return createFormatter(for: assetPrecision)
        }
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenAmountFormatter> {
        if asset?.identifier == WalletAssetId.usd.rawValue {
            let numberFormatter = createNumberFormatter(for: usdPrecision)
            return TokenAmountFormatter(numberFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: "",
                                        position: .prefix).localizableResource()
        } else {
            let numberFormatter = createNumberFormatter(for: assetPrecision)
            return TokenAmountFormatter(numberFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: " ",
                                        position: .suffix).localizableResource()
        }
    }

    private func createFormatter(for precision: Int) -> LocalizableResource<NumberFormatter> {
        createNumberFormatter(for: precision).localizableResource()
    }

    private func createNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.maximumFractionDigits = precision

        return formatter
    }
}
