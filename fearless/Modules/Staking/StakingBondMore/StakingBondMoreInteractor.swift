import RobinHood
import IrohaCrypto
import BigInt

final class StakingBondMoreInteractor {
    weak var presenter: StakingBondMoreInteractorOutputProtocol!

    private let priceProvider: AnySingleValueProvider<PriceData>
    private let balanceProvider: AnyDataProvider<DecodedAccountInfo>
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol

    init(
        priceProvider: AnySingleValueProvider<PriceData>,
        balanceProvider: AnyDataProvider<DecodedAccountInfo>,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            let priceData = changes.reduceToLastChange()
            self?.presenter.didReceive(price: priceData)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
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
            self?.presenter.didReceive(error: error)
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
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subscribeToAccountChanges()
    }

    private func createExtrinsicBuilderClosure(amount: BigUInt) -> ExtrinsicBuilderClosure {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            let call = try callFactory.bondExtra(amount: amount)
            _ = try builder.adding(call: call)
            return builder
        }

        return closure
    }

    func estimateFee(amount: BigUInt) {
        let closure = createExtrinsicBuilderClosure(amount: amount)
        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(paymentInfo: info, for: amount)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }
}
