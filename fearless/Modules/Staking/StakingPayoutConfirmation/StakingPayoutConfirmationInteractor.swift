import Foundation
import SoraKeystore

final class StakingPayoutConfirmationInteractor {
    let extrinsicService: ExtrinsicServiceProtocol
    let signer: SigningWrapperProtocol
    let settings: SettingsManagerProtocol
    let payouts: [PayoutInfo]

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol!

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        settings: SettingsManagerProtocol,
        payouts: [PayoutInfo]
    ) {
        self.extrinsicService = extrinsicService
        self.signer = signer
        self.settings = settings
        self.payouts = payouts
    }

    // MARK: - Private functions

    private func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let controllerAddress = selectedAccount.address

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            try self.payouts.forEach { payout in
                let payoutCall = try callFactory.payout(
                    validatorAddress: controllerAddress,
                    era: payout.era
                )

                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
    }
}

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        // TODO: Setup interactor
    }

    func submitPayout(for lastBalance: Decimal, lastFee: Decimal) {
        guard lastBalance >= lastFee else {
            presenter.didFailPayout(error: StakingConfirmError.notEnoughFunds)
            return
        }

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
