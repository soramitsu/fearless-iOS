import UIKit

enum AccountScoreRate {
    case low
    case medium
    case high

    init(from score: Decimal) {
        if score < 0.25 {
            self = .low
        } else if score < 0.75 {
            self = .medium
        } else {
            self = .high
        }
    }

    var color: UIColor? {
        switch self {
        case .low:
            return R.color.colorRed()
        case .medium:
            return R.color.colorOrange()
        case .high:
            return R.color.colorGreen()
        }
    }
}

class AccountScoreViewModel {
    private let fetcher: AccountStatisticsFetching
    let address: String

    weak var view: AccountScoreView?

    init(fetcher: AccountStatisticsFetching, address: String) {
        self.fetcher = fetcher
        self.address = address
    }

    func setup(with view: AccountScoreView?) {
        self.view = view

        Task {
            do {
                let stream = try await fetcher.subscribeForStatistics(address: address, cacheOptions: .onAll)
                for try await statistics in stream {
                    handle(response: statistics.value)
                }
            } catch {
                print("Account statistics fetching error: ", error)
            }
        }
    }

    private func handle(response: AccountStatisticsResponse?) {
        guard let score = response?.data?.score else {
            return
        }

        let rate = AccountScoreRate(from: score)
        let intScore = ((score * 100.0) as NSDecimalNumber).intValue

        DispatchQueue.main.async { [weak self] in
            self?.view?.bind(score: intScore, rate: rate)
        }
    }
}
