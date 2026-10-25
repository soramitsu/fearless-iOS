import Foundation
import SSFNetwork

protocol AccountStatisticsFetching {
    func subscribeForStatistics(
        address: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error>

    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse?
}
