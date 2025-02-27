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
        address: String,
        cacheOptions: CachedNetworkRequestTrigger
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<AccountStatisticsResponse>, any Error> {
        if let value = cache[address] {
            return AsyncThrowingStream(unfolding: { CachedNetworkResponse(value: AccountStatisticsResponse(data: value), type: .cache) } )
        }
        
        let stream = try await fetcher.subscribeForStatistics(address: address, cacheOptions: cacheOptions)
        
        return stream
    }
    
    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse? {
        if let value = cache[address] {
            return AccountStatisticsResponse(data: value)
        }
        
        return try await fetcher.fetchStatistics(address: address)
    }
    
    
}
