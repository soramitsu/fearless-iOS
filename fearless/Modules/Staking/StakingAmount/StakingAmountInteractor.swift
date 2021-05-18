import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import BigInt
import FearlessUtils

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol!

    private let repository: AnyDataProviderRepository<AccountItem>
    private let priceProvider: AnySingleValueProvider<PriceData>
    private let balanceProvider: AnyDataProvider<DecodedAccountInfo>
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let rewardService: RewardCalculatorServiceProtocol
    private let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        repository: AnyDataProviderRepository<AccountItem>,
        priceProvider: AnySingleValueProvider<PriceData>,
        balanceProvider: AnyDataProvider<DecodedAccountInfo>,
        extrinsicService: ExtrinsicServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.extrinsicService = extrinsicService
        self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.operationManager = operationManager
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

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(calculator: engine)
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }

    private func provideMinimumAmount() {
        let wrapper = eraInfoOperationFactory.networkStakingOperation()

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(minimalAmount: info.minimalStake)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subscribeToAccountChanges()
        provideRewardCalculator()
        provideMinimumAmount()
    }

    func fetchAccounts() {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let accounts = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(accounts: accounts)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<AccountItem>
    ) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let bondCall = try callFactory.bond(
                amount: amount,
                controller: address,
                rewardDestination: rewardDestination.accountAddress
            )

            let targets = Array(
                repeating: SelectedValidatorInfo(address: address),
                count: SubstrateConstants.maxNominations
            )
            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
                .adding(call: nominateCall)
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(
                    paymentInfo: info,
                    for: amount,
                    rewardDestination: rewardDestination
                )
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }
}
