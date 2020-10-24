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
            return createUsdNumberFormatter(for: usdPrecision).localizableResource()
        } else {
            return createTokenNumberFormatter(for: assetPrecision).localizableResource()
        }
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenAmountFormatter> {
        if asset?.identifier == WalletAssetId.usd.rawValue {
            let numberFormatter = createUsdNumberFormatter(for: usdPrecision)
            return TokenAmountFormatter(numberFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: "",
                                        position: .prefix).localizableResource()
        } else {
            let numberFormatter = createTokenNumberFormatter(for: assetPrecision)
            return TokenAmountFormatter(numberFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: " ",
                                        position: .suffix).localizableResource()
        }
    }

    private func createUsdNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.maximumFractionDigits = precision

        return formatter
    }

    private func createTokenNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = precision

        return formatter
    }
}
