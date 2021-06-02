import UIKit

final class AnalyticsInteractor {
    weak var presenter: AnalyticsInteractorOutputProtocol!

    let analyticsService: AnalyticsService?

    init(analyticsService: AnalyticsService?) {
        self.analyticsService = analyticsService
    }

    private func fetchAnalyticsRewards() {
        analyticsService?.start { [weak presenter] result in
            DispatchQueue.main.async {
                presenter?.didReceieve(rewardItemData: result)
            }
        }
    }
}

extension AnalyticsInteractor: AnalyticsInteractorInputProtocol {
    func setup() {
        fetchAnalyticsRewards()
    }
}
