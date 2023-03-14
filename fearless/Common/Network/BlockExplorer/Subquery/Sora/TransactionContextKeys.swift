import Foundation

enum TransactionContextKeys {
    static let extrinsicHash = "extrinsicHash"
    static let blockHash = "blockHash"
    static let referralTransactionType = "referralTransactionType"
    static let sender = "sender"
    static let referrer = "referrer"
    static let referral = "referral"
    static let era = "era"

    static let transactionType: String = "transaction_type"
    static let estimatedAmount: String = "estimatedAmount"
    static let slippage: String = "possibleSlippage"
    static let desire: String = "desiredOutput"
    static let marketType: String = "marketType"
    static let minMaxValue: String = "minMaxValue"

    // pools
    static let dex: String = "dex"
    static let shareOfPool: String = "shareOfPoo"
    static let firstAssetAmount: String = "firstAssetAmount"
    static let secondAssetAmount: String = "secondAssetAmount"
    static let firstReserves: String = "firstReserves"
    static let totalIssuances: String = "totalIssuances"
    static let directExchangeRateValue: String = "directExchangeRateValue"
    static let inversedExchangeRateValue: String = "inversedExchangeRateValue"
    static let sbApy: String = "sbApy"
}
