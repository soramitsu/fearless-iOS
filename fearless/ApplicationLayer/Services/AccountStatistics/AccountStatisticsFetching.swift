import Foundation
import SSFNetwork

protocol AccountStatisticsFetching {
    func subscribeForStatistics(
        address: String
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<AccountStatisticsResponse>, Error>

    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse?
}
