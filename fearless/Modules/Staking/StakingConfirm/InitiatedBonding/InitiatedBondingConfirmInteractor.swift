import Foundation
import RobinHood
import SoraKeystore

final class InitiatedBondingConfirmInteractor: StakingBaseConfirmInteractor {
    let nomination: PreparedNomination<InitiatedBonding>
    let settings: SettingsManagerProtocol

    init(priceProvider: AnySingleValueProvider<PriceData>,
         balanceProvider: AnyDataProvider<DecodedAccountInfo>,
         extrinsicService: ExtrinsicServiceProtocol,
         operationManager: OperationManagerProtocol,
         signer: SigningWrapperProtocol,
         settings: SettingsManagerProtocol,
         nomination: PreparedNomination<InitiatedBonding>) {
        self.nomination = nomination
        self.settings = settings

        super.init(priceProvider: priceProvider,
                   balanceProvider: balanceProvider,
                   extrinsicService: extrinsicService,
                   operationManager: operationManager,
                   signer: signer)
    }

    private func provideConfirmationModel() {
        guard let selectedAccount = settings.selectedAccount else {
            return
        }

        let rewardDestination: RewardDestination<DisplayAddress> = {
            switch nomination.bonding.rewardDestination {
            case .restake:
                return .restake
            case .payout(let account):
                let displayAddress = DisplayAddress(address: account.address,
                                                    username: account.username)
                return .payout(account: displayAddress)
            }
        }()

        let stash = DisplayAddress(address: selectedAccount.address,
                                   username: selectedAccount.username)

        let confirmation = StakingConfirmationModel(wallet: stash,
                                                    amount: nomination.bonding.amount,
                                                    rewardDestination: rewardDestination,
                                                    targets: nomination.targets,
                                                    maxTargets: nomination.maxTargets)

        presenter.didReceive(model: confirmation)
    }

    private func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let networkType = settings.selectedConnection.type

        guard let amount = nomination.bonding.amount
                .toSubstrateAmount(precision: networkType.precision) else {
            return nil
        }

        let controllerAddress = selectedAccount.address
        let rewardDestination = nomination.bonding.rewardDestination.accountAddress
        let targets = nomination.targets

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let bondCall = try callFactory.bond(amount: amount,
                                                controller: controllerAddress,
                                                rewardDestination: rewardDestination)

            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
                .adding(call: nominateCall)
        }

        return closure
    }

    override func setup() {
        provideConfirmationModel()

        super.setup()
    }

    override func estimateFee() {
        guard let closure = createExtrinsicBuilderClosure() else {
            return
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

    override func submitNomination(for lastBalance: Decimal, lastFee: Decimal) {
        guard lastBalance >= nomination.bonding.amount  + lastFee else {
            presenter.didFailNomination(error: StakingConfirmError.notEnoughFunds)
            return
        }

        guard let closure = createExtrinsicBuilderClosure() else {
            return
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
