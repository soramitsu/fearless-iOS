import Foundation
import Web3
import SSFModels

struct AssetAmountValues {
    let asset: AssetModel
    let amount: BigUInt
    let priceData: PriceData?

    var decimalAmount: Decimal {
        let balance = Decimal.fromSubstrateAmount(
            amount,
            precision: Int16(asset.precision)
        )

        return balance ?? 0
    }

    var fiatAmount: Decimal {
        guard let priceData = priceData,
              let priceDecimal = Decimal(string: priceData.price)
        else {
            return 0
        }

        return priceDecimal * decimalAmount
    }
}
