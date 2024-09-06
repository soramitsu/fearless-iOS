import Foundation
import SSFModels
import BigInt

enum OKXDexError: Error {
    case minimumAmount(text: String?)
    case maximumAmount(text: String?)
    case unknown(text: String?)

    func decode(with chainAsset: ChainAsset) -> String? {
        switch self {
        case let .minimumAmount(text):
            let amountString = text?.digits
            let amount = amountString.flatMap { BigUInt(string: $0) }
            let amountDecimal = amount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) }

            return amountDecimal.flatMap { "Minimum amount is \($0) \(chainAsset.asset.symbolUppercased)" }
        case let .maximumAmount(text):
            let amountString = text?.digits
            let amount = amountString.flatMap { BigUInt(string: $0) }
            let amountDecimal = amount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) }

            return amountDecimal.flatMap { "Maximum amount is \($0) \(chainAsset.asset.symbolUppercased)" }
        case let .unknown(text):
            return text
        }
    }
}
