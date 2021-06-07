import Foundation
import RobinHood

class StakingBaseConfirmInteractor: StakingConfirmInteractorInputProtocol {
    weak var presenter: StakingConfirmInteractorOutputProtocol!

    let priceProvider: AnySingleValueProvider<PriceData>
    let balanceProvider: AnyDataProvider<DecodedAccountInfo>
    let extrinsicService: ExtrinsicServiceProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol

    init(
        priceProvider: AnySingleValueProvider<PriceData>,
        balanceProvider: AnyDataProvider<DecodedAccountInfo>,
        extrinsicService: ExtrinsicServiceProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol
    ) {
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.extrinsicService = extrinsicService
        self.operationManager = operationManager
        self.signer = signer
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(price: nil)
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(price: item)
                    case .delete:
                        self?.presenter.didReceive(price: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(priceError: error)
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

    private func subscribeToAccountChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            let balanceItem = changes.reduceToLastChange()?.item?.data
            self?.presenter.didReceive(balance: balanceItem)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(balanceError: error)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        balanceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    // MARK: StakingConfirmInteractorInputProtocol

    func setup() {
        subscribeToAccountChanges()
        subscribeToPriceChanges()
    }

    func submitNomination(for _: Decimal, lastFee _: Decimal) {}

    func estimateFee() {}
}
