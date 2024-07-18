import Foundation

struct AccountStatisticsResponse: Decodable {
    let data: AccountStatistics?
}

struct AccountStatistics: Decodable {
    let score: Decimal?
    let stats: AccountStatisticsData?
}

struct AccountStatisticsData: Decodable {
    let nativeBalanceUSD: Decimal?
    let holdTokensBalanceUSD: Decimal?
    let walletAge: Int?
    let totalTransactions: Int?
    let totalRejectedTransactions: Int?
    let averageTransactionTime: Decimal?
    let maxTransactionTime: Decimal?
    let minTransactionTime: Decimal?
}
