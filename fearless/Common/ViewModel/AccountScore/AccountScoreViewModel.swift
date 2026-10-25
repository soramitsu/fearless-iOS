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
    private let logger: LoggerProtocol?

    let address: String?
    var scoringEnabled: Bool

    private weak var view: AccountScoreView?
    private var viewIdentifier: ObjectIdentifier?
    private var bindingIdentifier: UUID?
    private var subscriptionTask: Task<Void, Never>?

    init(
        fetcher: AccountStatisticsFetching,
        address: String?,
        chain: ChainModel?,
        settings: SettingsManagerProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol?
    ) {
        self.fetcher = fetcher
        self.address = address
        self.chain = chain
        self.settings = settings
        self.eventCenter = eventCenter
        self.logger = logger

        scoringEnabled = (chain?.isNomisSupported == true || chain == nil)
            && settings.accountScoreEnabled == true && address?.isNotEmpty == true
    }

    func setup(with view: AccountScoreView?) {
        subscriptionTask?.cancel()
        let bindingIdentifier = UUID()
        self.bindingIdentifier = bindingIdentifier
        viewIdentifier = view.map(ObjectIdentifier.init)
        eventCenter.add(observer: self)
        self.view = view

        guard view != nil, let address else {
            return
        }

        subscriptionTask = Task { [weak self, fetcher, logger] in
            do {
                let stream = try await fetcher.subscribeForStatistics(address: address)

                do {
                    for try await statistics in stream {
                        guard !Task.isCancelled else { return }
                        await MainActor.run { [weak self] in
                            self?.handle(response: statistics, bindingIdentifier: bindingIdentifier)
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    logger?.debug("Account statistics fetching error: \(error)")
                    await MainActor.run { [weak self] in
                        self?.handle(response: nil, bindingIdentifier: bindingIdentifier)
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                logger?.debug("Account statistics fetching error: \(error)")
            }
        }
    }

    func detach(from view: AccountScoreView) {
        guard viewIdentifier == ObjectIdentifier(view) else { return }
        bindingIdentifier = nil
        viewIdentifier = nil
        self.view = nil
        subscriptionTask?.cancel()
        subscriptionTask = nil
        eventCenter.remove(observer: self)
    }

    deinit {
        subscriptionTask?.cancel()
        eventCenter.remove(observer: self)
    }

    private func handle(response: AccountStatisticsResponse?, bindingIdentifier: UUID) {
        guard self.bindingIdentifier == bindingIdentifier, let view else { return }
        guard let score = response?.data?.score else {
            view.bindEmptyViewModel()
            return
        }

        let rate = AccountScoreRate(from: score)
        let intScore = ((score * 100.0) as NSDecimalNumber).intValue

        view.bind(score: intScore, rate: rate)
    }
}

extension AccountScoreViewModel: EventVisitorProtocol {
    func processAccountScoreSettingsChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let view = self.view else { return }
            self.scoringEnabled = (self.chain?.isNomisSupported == true || self.chain == nil)
                && self.settings.accountScoreEnabled == true && self.address?.isNotEmpty == true
            view.bind(viewModel: self)
        }
    }
}
