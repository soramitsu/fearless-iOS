import UIKit
import RobinHood

final class StakingConfirmInteractor {
    weak var presenter: StakingConfirmInteractorOutputProtocol!

    private let priceProvider: SingleValueProvider<PriceData>
    private let balanceProvider: DataProvider<DecodedAccountInfo>
    private let extrinsicService: ExtrinsicServiceProtocol
    private let operationManager: OperationManagerProtocol

    init(priceProvider: SingleValueProvider<PriceData>,
         balanceProvider: DataProvider<DecodedAccountInfo>,
         extrinsicService: ExtrinsicServiceProtocol,
         operationManager: OperationManagerProtocol) {
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.extrinsicService = extrinsicService
        self.operationManager = operationManager
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(price: nil)
            } else {
                for change in changes {
                    switch change {
                    case .insert(let item), .update(let item):
                        self?.presenter.didReceive(price: item)
                    case .delete:
                        self?.presenter.didReceive(price: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        priceProvider.addObserver(self,
                                  deliverOn: .main,
                                  executing: updateClosure,
                                  failing: failureClosure,
                                  options: options)
    }

    private func subscribeToAccountChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(balance: nil)
            } else {
                for change in changes {
                    switch change {
                    case .insert(let wrapped), .update(let wrapped):
                        self?.presenter.didReceive(balance: wrapped.item.data)
                    case .delete:
                        self?.presenter.didReceive(balance: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        balanceProvider.addObserver(self,
                                    deliverOn: .main,
                                    executing: updateClosure,
                                    failing: failureClosure,
                                    options: options)
    }
}

extension StakingConfirmInteractor: StakingConfirmInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subscribeToAccountChanges()
    }
}
