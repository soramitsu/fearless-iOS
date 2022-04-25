import Foundation
import SoraFoundation

protocol AssetBalanceFormatterFactoryProtocol {
    func createInputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter>

    func createDisplayFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<LocalizableDecimalFormatting>

    func createTokenFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<TokenFormatter>

    func createFeeTokenFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<TokenFormatter>
}

class AssetBalanceFormatterFactory {
    private func createTokenFormatterCommon(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode
    ) -> LocalizableResource<TokenFormatter> {
        let formatter = createCompoundFormatter(for: info.displayPrecision, roundingMode: roundingMode)

        let tokenFormatter = TokenFormatter(
            decimalFormatter: formatter,
            tokenSymbol: info.symbol,
            separator: info.symbolValueSeparator,
            position: info.symbolPosition
        )

        return LocalizableResource { locale in
            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }

    // swiftlint:disable function_body_length
    private func createCompoundFormatter(
        for preferredPrecision: UInt16,
        roundingMode: NumberFormatter.RoundingMode = .down
    ) -> LocalizableDecimalFormatting {
        let abbreviations: [BigNumberAbbreviation] = [
            BigNumberAbbreviation(
                threshold: 0,
                divisor: 1.0,
                suffix: "",
                formatter: DynamicPrecisionFormatter(
                    preferredPrecision: UInt8(preferredPrecision),
                    roundingMode: roundingMode
                )
            ),
            BigNumberAbbreviation(
                threshold: 1,
                divisor: 1.0,
                suffix: "",
                formatter: NumberFormatter.decimalFormatter(
                    precision: Int(preferredPrecision),
                    rounding: roundingMode,
                    usesIntGrouping: true
                )
            ),
            BigNumberAbbreviation(
                threshold: 10,
                divisor: 1.0,
                suffix: "",
                formatter: nil
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
            rounding: roundingMode,
            usesIntGrouping: true
        )
    }
}

extension AssetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol {
    func createInputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.maximumFractionDigits = Int(info.assetPrecision)
        return formatter.localizableResource()
    }

    func createDisplayFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<LocalizableDecimalFormatting> {
        let formatter = createCompoundFormatter(for: info.displayPrecision)
        return LocalizableResource { locale in
            formatter.locale = locale
            return formatter
        }
    }

    func createTokenFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatterCommon(for: info, roundingMode: .down)
    }

    func createFeeTokenFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatterCommon(for: info, roundingMode: .up)
    }
}
