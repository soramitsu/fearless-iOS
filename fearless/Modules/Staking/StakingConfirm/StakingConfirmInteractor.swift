import UIKit
import RobinHood
import BigInt

final class StakingConfirmInteractor {
    weak var presenter: StakingConfirmInteractorOutputProtocol!

    private let priceProvider: SingleValueProvider<PriceData>
    private let balanceProvider: DataProvider<DecodedAccountInfo>
    private let extrinsicService: ExtrinsicServiceProtocol
    private let signer: SigningWrapperProtocol
    private let operationManager: OperationManagerProtocol

    init(priceProvider: SingleValueProvider<PriceData>,
         balanceProvider: DataProvider<DecodedAccountInfo>,
         extrinsicService: ExtrinsicServiceProtocol,
         operationManager: OperationManagerProtocol,
         signer: SigningWrapperProtocol) {
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
                    case .insert(let item), .update(let item):
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
            self?.presenter.didReceive(balanceError: error)
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

    func estimateFee(controller: AccountItem,
                     amount: BigUInt,
                     rewardDestination: RewardDestination,
                     targets: [SelectedValidatorInfo]) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let bondCall = try callFactory.bond(amount: amount,
                                                controller: controller.address,
                                                rewardDestination: rewardDestination)

            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
                .adding(call: nominateCall)
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case .success(let info):
                self?.presenter.didReceive(paymentInfo: info)
            case .failure(let error):
                self?.presenter.didReceive(feeError: error)
            }
        }
    }

    func submitNomination(controller: AccountItem,
                          amount: BigUInt,
                          rewardDestination: RewardDestination,
                          targets: [SelectedValidatorInfo]) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let bondCall = try callFactory.bond(amount: amount,
                                                controller: controller.address,
                                                rewardDestination: rewardDestination)

            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
                .adding(call: nominateCall)
        }

        presenter.didStartNomination()

        extrinsicService.submit(closure,
                                signer: signer,
                                runningIn: .main) { [weak self] result in
            switch result {
            case .success(let txHash):
                self?.presenter.didCompleteNomination(txHash: txHash)
            case .failure(let error):
                self?.presenter.didFailNomination(error: error)
            }
        }
    }
}
