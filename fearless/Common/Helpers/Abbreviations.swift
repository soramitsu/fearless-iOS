import Foundation
import SoraFoundation

protocol AbbreviationsFactoryProtocol {
    func abbreviations(for locale: FormatterLocale) -> [BigNumberAbbreviation]
}

struct AbbreviationsFactory {
    private let preferredPrecision: Int
    private let roundingMode: NumberFormatter.RoundingMode

    init(preferredPrecision: Int, roundingMode: NumberFormatter.RoundingMode) {
        self.preferredPrecision = preferredPrecision
        self.roundingMode = roundingMode
    }

    func abbreviations(
        for locale: FormatterLocale
    ) -> [BigNumberAbbreviation] {
        switch locale {
        case .japanese:
            return japanese()
        case .chinese:
            return chinese()
        case .usual:
            return usual()
        }
    }

    private func japanese() -> [BigNumberAbbreviation] {
        [BigNumberAbbreviation(
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
                precision: preferredPrecision,
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
            threshold: 10000,
            divisor: 10000.0,
            suffix: "万",
            formatter: nil
        ),
        BigNumberAbbreviation(
            threshold: 100_000_000,
            divisor: 100_000_000.0,
            suffix: "億",
            formatter: nil
        ),
        BigNumberAbbreviation(
            threshold: 1_000_000_000_000,
            divisor: 1_000_000_000_000.0,
            suffix: "兆",
            formatter: nil
        )]
    }

    private func chinese() -> [BigNumberAbbreviation] {
        [BigNumberAbbreviation(
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
                precision: preferredPrecision,
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
            threshold: 10000,
            divisor: 10000.0,
            suffix: "-万",
            formatter: nil
        ),
        BigNumberAbbreviation(
            threshold: 100_000_000,
            divisor: 100_000_000.0,
            suffix: "-亿",
            formatter: nil
        )]
    }

    private func usual() -> [BigNumberAbbreviation] {
        [
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
                    precision: preferredPrecision,
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
    }
}
