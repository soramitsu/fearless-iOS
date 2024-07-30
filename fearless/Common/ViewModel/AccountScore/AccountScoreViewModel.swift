import UIKit
import SoraKeystore
import SSFModels

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
            return R.color.colorOrange()
        case .medium:
            return R.color.colorYellow()
        case .high:
            return R.color.colorGreen()
        }
    }
}

class AccountScoreViewModel {
    private let eventCenter: EventCenterProtocol
    private let fetcher: AccountStatisticsFetching
    private let chain: ChainModel?
    private let settings: SettingsManagerProtocol
    let address: String?
    var scoringEnabled: Bool

    weak var view: AccountScoreView?

    init(
        fetcher: AccountStatisticsFetching,
        address: String?,
        chain: ChainModel?,
        settings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.fetcher = fetcher
        self.address = address
        self.chain = chain
        self.settings = settings
        self.eventCenter = eventCenter

        scoringEnabled = (chain?.isNomisSupported == true || chain == nil) && settings.accountScoreEnabled == true
    }

    func setup(with view: AccountScoreView?) {
        eventCenter.add(observer: self)
        self.view = view

        guard let address else {
            return
        }

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
            view?.bindEmptyViewModel()
            return
        }

        let rate = AccountScoreRate(from: score)
        let intScore = ((score * 100.0) as NSDecimalNumber).intValue

        DispatchQueue.main.async { [weak self] in
            self?.view?.bind(score: intScore, rate: rate)
        }
    }
}

extension AccountScoreViewModel: EventVisitorProtocol {
    func processAccountScoreSettingsChanged() {
        scoringEnabled = (chain?.isNomisSupported == true || chain == nil) && settings.accountScoreEnabled == true

        DispatchQueue.main.async { [weak self] in
            self?.view?.bind(viewModel: self)
        }
    }
}
