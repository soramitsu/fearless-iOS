import Foundation
import SoraKeystore
import CommonWallet
import RobinHood
import IrohaCrypto

final class StakingPayoutConfirmationInteractor {
    private let extrinsicService: ExtrinsicServiceProtocol
    private let signer: SigningWrapperProtocol
    private let balanceProvider: AnyDataProvider<DecodedAccountInfo>
    private let priceProvider: AnySingleValueProvider<PriceData>
    private let settings: SettingsManagerProtocol
    private let payouts: [PayoutInfo]

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol!

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        balanceProvider: AnyDataProvider<DecodedAccountInfo>,
        priceProvider: AnySingleValueProvider<PriceData>,
        settings: SettingsManagerProtocol,
        payouts: [PayoutInfo]
    ) {
        self.extrinsicService = extrinsicService
        self.signer = signer
        self.balanceProvider = balanceProvider
        self.priceProvider = priceProvider
        self.settings = settings
        self.payouts = payouts
    }

    // MARK: - Private functions

    private func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            try self.payouts.forEach { payout in
                let payoutCall = try callFactory.payout(
                    validatorId: payout.validator,
                    era: payout.era
                )

                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
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
}

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        subscribeToAccountChanges()
    }

    func submitPayout() {
        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        presenter.didStartPayout()

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(txHash):
                self?.presenter.didCompletePayout(txHash: txHash)
            case let .failure(error):
                self?.presenter.didFailPayout(error: error)
            }
        }
    }

    func estimateFee() {
        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.presenter.didReceive(feeError: error)
            }
        }
    }
}
