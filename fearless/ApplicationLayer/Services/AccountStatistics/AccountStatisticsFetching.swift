import Foundation
import SSFNetwork

protocol AccountStatisticsFetching {
    func subscribeForStatistics(
        address: String,
        cacheOptions: CachedNetworkRequestTrigger
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<AccountStatisticsResponse>, Error>

    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse?
}
