import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import BigInt
import FearlessUtils

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol!

    private let repository: AnyDataProviderRepository<AccountItem>
    private let priceProvider: SingleValueProvider<PriceData>
    private let balanceProvider: DataProvider<DecodedAccountInfo>
    private let extrinsicService: ExtrinsicServiceProtocol
    private let operationManager: OperationManagerProtocol

    init(repository: AnyDataProviderRepository<AccountItem>,
         priceProvider: SingleValueProvider<PriceData>,
         balanceProvider: DataProvider<DecodedAccountInfo>,
         extrinsicService: ExtrinsicServiceProtocol,
         operationManager: OperationManagerProtocol) {
        self.repository = repository
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
        balanceProvider.addObserver(self,
                                    deliverOn: .main,
                                    executing: updateClosure,
                                    failing: failureClosure,
                                    options: options)
    }
}

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subscribeToAccountChanges()
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

    func estimateFee(for address: String, amount: BigUInt, rewardDestination: RewardDestination) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let addressFactory = SS58AddressFactory()
            let accountId = try addressFactory.accountId(from: address)

            let destArg: RewardDestinationArg

            switch rewardDestination {
            case .restake:
                destArg = .staked
            case .payout(let address):
                let accountId = try addressFactory.accountId(from: address)
                destArg = .account(accountId)
            }

            let bondCall = BondCall(controller: .accoundId(accountId),
                                    value: amount,
                                    payee: destArg)

            let targets = Array(repeating: MultiAddress.accoundId(accountId),
                                count: SubstrateConstants.maxNominations)
            let nominateCall = NominateCall(targets: targets)

            return try builder
                .adding(call: RuntimeCall<BondCall>.bond(bondCall))
                .adding(call: RuntimeCall<NominateCall>.nominate(nominateCall))
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case .success(let info):
                self?.presenter.didReceive(paymentInfo: info,
                                           for: amount,
                                           rewardDestination: rewardDestination)
            case .failure(let error):
                self?.presenter.didReceive(error: error)
            }
        }
    }
}
