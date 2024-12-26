protocol OKXSyncService {
    func syncUp()
}

final class OKXSyncServiceImpl: OKXSyncService {
    private let okxService: OKXDexAggregatorService

    init(okxService: OKXDexAggregatorService) {
        self.okxService = okxService
    }

    func syncUp() {
        Task {
            do {
                let availableChains = try await okxService.fetchAvailableChains(preferredDataSourceType: .remote)
                let parameters = OKXDexAllTokensRequestParameters(chainId: nil)
                let availableTokens = try await okxService.fetchAllTokens(parameters: parameters, preferredDataSourceType: .remote)
            } catch {
                print(error)
            }
        }
    }
}
