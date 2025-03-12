import SSFNetwork

final class AccountScoreRepository {
    private let fetcher: AccountStatisticsFetching
    
    private var cache: [String: AccountStatistics] = [:]
    
    init(fetcher: AccountStatisticsFetching) {
        self.fetcher = fetcher
    }
}

extension AccountScoreRepository: AccountStatisticsFetching {
    func subscribeForStatistics(
        address: String
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<AccountStatisticsResponse>, any Error> {
        let stream = try await fetcher.subscribeForStatistics(address: address)
        
        return stream
    }
    
    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse? {
        if let value = cache[address] {
            return AccountStatisticsResponse(data: value)
        }
        
        return try await fetcher.fetchStatistics(address: address)
    }
}
