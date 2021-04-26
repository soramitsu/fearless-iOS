import UIKit
import RobinHood

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!
    private let priceProvider: AnySingleValueProvider<PriceData>

    init(priceProvider: AnySingleValueProvider<PriceData>) {
        self.priceProvider = priceProvider
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(priceResult: .success(nil))
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(priceResult: .success(item))
                    case .delete:
                        self?.presenter.didReceive(priceResult: .success(nil))
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            DispatchQueue.main.async {
                self?.presenter.didReceive(priceResult: .failure(error))
            }
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
    }
}
