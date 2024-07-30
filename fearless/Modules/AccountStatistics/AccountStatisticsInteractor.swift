import UIKit

protocol AccountStatisticsInteractorOutput: AnyObject {
    func didReceiveAccountStatistics(_ response: AccountStatisticsResponse?)
    func didReceiveAccountStatisticsError(_ error: Error)
    func didReceiveNoDataAvailableState()
}

final class AccountStatisticsInteractor {
    // MARK: - Private properties

    private weak var output: AccountStatisticsInteractorOutput?
    private let accountScoreFetcher: AccountStatisticsFetching
    private let address: String?

    init(accountScoreFetcher: AccountStatisticsFetching, address: String?) {
        self.accountScoreFetcher = accountScoreFetcher
        self.address = address
    }
}

// MARK: - AccountStatisticsInteractorInput

extension AccountStatisticsInteractor: AccountStatisticsInteractorInput {
    func setup(with output: AccountStatisticsInteractorOutput) {
        self.output = output
    }

    func fetchAccountStatistics() {
        guard let address else {
            output?.didReceiveNoDataAvailableState()
            return
        }
        Task {
            do {
                let stream = try await accountScoreFetcher.subscribeForStatistics(address: address, cacheOptions: .onAll)

                for try await accountScore in stream {
                    output?.didReceiveAccountStatistics(accountScore.value)
                }
            } catch {
                output?.didReceiveAccountStatisticsError(error)
            }
        }
    }
}
