import Foundation
import CommonWallet
import SoraFoundation

struct AmountFormatterFactory: NumberFormatterFactoryProtocol {
    let assetPrecision: Int
    let usdPrecision: Int

    init(
        assetPrecision: Int = 4,
        usdPrecision: Int = 2
    ) {
        self.assetPrecision = assetPrecision
        self.usdPrecision = usdPrecision
    }

    func createInputFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount

        if let asset = asset {
            formatter.maximumFractionDigits = Int(asset.precision)
        }

        return formatter.localizableResource()
    }

    func createDisplayFormatter(for asset: WalletAsset?) -> LocalizableResource<LocalizableDecimalFormatting> {
        let precision = asset?.identifier == WalletAssetId.usd.rawValue ? usdPrecision : assetPrecision
        let formatter = createCompoundFormatter(for: precision)
        return LocalizableResource { locale in
            formatter.locale = locale
            return formatter
        }
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenFormatter> {
        let precision = asset?.identifier == WalletAssetId.usd.rawValue ? usdPrecision : assetPrecision
        let formatter = createCompoundFormatter(for: precision)

        if asset?.identifier == WalletAssetId.usd.rawValue {
            let tokenFormatter = TokenFormatter(
                decimalFormatter: formatter,
                tokenSymbol: asset?.symbol ?? "",
                separator: "",
                position: .prefix
            )

            return LocalizableResource { locale in
                tokenFormatter.locale = locale
                return tokenFormatter
            }
        } else {
            let tokenFormatter = TokenFormatter(
                decimalFormatter: formatter,
                tokenSymbol: asset?.symbol ?? "",
                separator: " ",
                position: .suffix
            )

            return LocalizableResource { locale in
                tokenFormatter.locale = locale
                return tokenFormatter
            }
        }
    }

    private func createCompoundFormatter(for preferredPrecision: Int) -> LocalizableDecimalFormatting {
        let abbreviations: [BigNumberAbbreviation] = [
            BigNumberAbbreviation(
                threshold: 0,
                divisor: 1.0,
                suffix: "",
                formatter: DynamicPrecisionFormatter(
                    preferredPrecision: UInt8(preferredPrecision),
                    roundingMode: .down
                )
            ),
            BigNumberAbbreviation(
                threshold: 1,
                divisor: 1.0,
                suffix: "",
                formatter: NumberFormatter.decimalFormatter(
                    precision: preferredPrecision,
                    rounding: .down,
                    usesIntGrouping: true
                )
            ),
            BigNumberAbbreviation(
                threshold: 1000,
                divisor: 1.0,
                suffix: "",
                formatter: NumberFormatter.decimalFormatter(
                    precision: preferredPrecision,
                    rounding: .down,
                    usesIntGrouping: true
                )
            ),
            BigNumberAbbreviation(
                threshold: 1_000_000,
                divisor: 1_000_000.0,
                suffix: "M",
                formatter: nil
            ),
            BigNumberAbbreviation(
                threshold: 1_000_000_000,
                divisor: 1_000_000_000.0,
                suffix: "B",
                formatter: nil
            ),
            BigNumberAbbreviation(
                threshold: 1_000_000_000_000,
                divisor: 1_000_000_000_000.0,
                suffix: "T",
                formatter: nil
            )
        ]

        return BigNumberFormatter(
            abbreviations: abbreviations,
            precision: 2,
            rounding: .down,
            usesIntGrouping: true
        )
    }
}
