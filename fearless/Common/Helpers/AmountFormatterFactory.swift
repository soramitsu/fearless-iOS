import Foundation

import SoraFoundation

@available(*, deprecated, message: "Use AssetBalanceFormatterFactory instead")
struct AmountFormatterFactory: NumberFormatterFactoryProtocol {
    let assetPrecision: Int
    let usdPrecision: Int

    init(
        assetPrecision: Int = 5,
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
        return LocalizableResource { locale in
            let formatter = createCompoundFormatter(for: precision, for: FormatterLocale(locale: locale))
            formatter.locale = locale
            return formatter
        }
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenFormatter> {
        createCommonTokenFormatter(for: asset, roundingMode: .down)
    }

    func createFeeTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenFormatter> {
        createCommonTokenFormatter(for: asset, roundingMode: .up)
    }

    private func createCommonTokenFormatter(
        for asset: WalletAsset?,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<TokenFormatter> {
        let precision = asset?.identifier == WalletAssetId.usd.rawValue ? usdPrecision : assetPrecision
        let formatter = createCompoundFormatter(
            for: precision,
            roundingMode: roundingMode,
            for: .usual
        )

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

    // swiftlint:disable function_body_length
    private func createCompoundFormatter(
        for preferredPrecision: Int,
        roundingMode: NumberFormatter.RoundingMode = .down,
        for locale: FormatterLocale
    ) -> LocalizableDecimalFormatting {
        let abbreviationFactory = AbbreviationsFactory(
            preferredPrecision: preferredPrecision,
            roundingMode: roundingMode
        )

        return BigNumberFormatter(
            abbreviations: abbreviationFactory.abbreviations(for: locale),
            precision: 2,
            rounding: roundingMode,
            usesIntGrouping: true
        )
    }
}
