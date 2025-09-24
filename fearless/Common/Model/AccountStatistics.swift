import Foundation

struct AccountStatisticsResponse: Decodable {
    let data: AccountStatistics?
}

struct AccountStatistics: Decodable {
    let score: Decimal?
    let address: String?
    let stats: AccountStatisticsData?
}

struct AccountStatisticsData: Decodable {
    enum CodingKeys: String, CodingKey {
        case nativeBalanceUSD
        case holdTokensBalanceUSD
        case walletAge
        case totalTransactions
        case totalRejectedTransactions
        case averageTransactionTime
        case maxTransactionTime
        case minTransactionTime
        case scoredAt
    }

    let nativeBalanceUSD: Decimal?
    let holdTokensBalanceUSD: Decimal?
    let walletAge: Int?
    let totalTransactions: Int?
    let totalRejectedTransactions: Int?
    let averageTransactionTime: Decimal?
    let maxTransactionTime: Decimal?
    let minTransactionTime: Decimal?
    let scoredAt: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        nativeBalanceUSD = try? container.decodeIfPresent(Decimal.self, forKey: .nativeBalanceUSD)
        holdTokensBalanceUSD = try? container.decodeIfPresent(Decimal.self, forKey: .holdTokensBalanceUSD)
        walletAge = try? container.decodeIfPresent(Int.self, forKey: .walletAge)
        totalTransactions = try? container.decodeIfPresent(Int.self, forKey: .totalTransactions)
        totalRejectedTransactions = try? container.decodeIfPresent(Int.self, forKey: .totalRejectedTransactions)
        averageTransactionTime = try? container.decodeIfPresent(Decimal.self, forKey: .averageTransactionTime)
        maxTransactionTime = try? container.decodeIfPresent(Decimal.self, forKey: .maxTransactionTime)
        minTransactionTime = try? container.decodeIfPresent(Decimal.self, forKey: .minTransactionTime)
        scoredAt = try? container.decodeIfPresent(Date.self, forKey: .scoredAt)
    }
}
