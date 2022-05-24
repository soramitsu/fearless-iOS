import Foundation
import RobinHood
import BigInt

final class SelectValidatorsConfirmRelaychainExistingViewModelState: SelectValidatorsConfirmViewModelState {
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let existingBonding: ExistingBonding
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    var stateListener: SelectValidatorsConfirmModelStateListener?
    let operationManager: OperationManagerProtocol

    var confirmationModel: SelectValidatorsConfirmationModel?

    private(set) var balance: Decimal?
    private(set) var priceData: PriceData?
    private(set) var fee: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var minNominatorBond: Decimal?
    private(set) var counterForNominators: UInt32?
    private(set) var maxNominatorsCount: UInt32?
    private(set) var stakingDuration: StakingDuration?

    func setStateListener(_ stateListener: SelectValidatorsConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    init(
        targets: [SelectedValidatorInfo],
        maxTargets: Int,
        existingBonding: ExistingBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        operationManager: OperationManagerProtocol
    ) {
        self.targets = targets
        self.maxTargets = maxTargets
        self.existingBonding = existingBonding
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.operationManager = operationManager
    }

    private func createRewardDestinationOperation(
        for payoutAddress: String
    ) -> CompoundOperationWrapper<RewardDestination<DisplayAddress>> {
        let mapOperation: BaseOperation<RewardDestination<DisplayAddress>> = ClosureOperation {
            let displayAddress = DisplayAddress(
                address: self.wallet.fetch(for: self.chainAsset.chain.accountRequest())?.toAddress() ?? payoutAddress,
                username: self.wallet.name
            )

            return RewardDestination.payout(account: displayAddress)
        }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: []
        )
    }

    private func provideChangeTargetsConfirmationModel() {
        let rewardDestWrapper: CompoundOperationWrapper<RewardDestination<DisplayAddress>> = {
            switch existingBonding.rewardDestination {
            case .restake:
                return CompoundOperationWrapper.createWithResult(RewardDestination<DisplayAddress>.restake)
            case let .payout(address):
                return createRewardDestinationOperation(for: address)
            }
        }()

        let currentMaxTargets = maxTargets
        let currentTargets = targets
        let currentBonding = existingBonding

        let mapOperation: BaseOperation<SelectValidatorsConfirmationModel> = ClosureOperation {
            let controller = currentBonding.controllerAccount
            let rewardDestination = try rewardDestWrapper.targetOperation.extractNoCancellableResultData()

            let controllerDisplayAddress = DisplayAddress(
                address: controller.toAddress() ?? "",
                username: controller.name
            )

            return SelectValidatorsConfirmationModel(
                wallet: controllerDisplayAddress,
                amount: currentBonding.amount,
                rewardDestination: rewardDestination,
                targets: currentTargets,
                maxTargets: currentMaxTargets,
                hasExistingBond: true,
                hasExistingNomination: currentBonding.selectedTargets != nil
            )
        }

        let dependencies = rewardDestWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        mapOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                do {
                    self?.confirmationModel = try mapOperation.extractNoCancellableResultData()

                    self?.stateListener?.provideConfirmationState(viewModelState: strongSelf)
                } catch {
                    self?.stateListener?.didReceiveError(error: error)
                }
            }
        }

        operationManager.enqueue(operations: dependencies + [mapOperation], in: .transient)
    }

    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        let targets = targets

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: nominateCall)
        }

        return closure
    }
}

extension SelectValidatorsConfirmRelaychainExistingViewModelState: SelectValidatorsConfirmRelaychainExistingStrategyOutput {
    func didSetup() {
        provideChangeTargetsConfirmationModel()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.available {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = 0.0
            }

            stateListener?.provideAsset(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMinBond(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minBond):
            minNominatorBond = minBond.map {
                Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
            } ?? nil
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(maxNominatorsCount):
            self.maxNominatorsCount = maxNominatorsCount
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveCounterForNominators(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(counterForNominators):
            self.counterForNominators = counterForNominators
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveStakingDuration(result: Result<StakingDuration, Error>) {
        switch result {
        case let .success(duration):
            stakingDuration = duration
            stateListener?.provideHints(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didStartNomination() {
        stateListener?.didStartNomination()
    }

    func didCompleteNomination(txHash: String) {
        stateListener?.didCompleteNomination(txHash: txHash)
    }

    func didFailNomination(error: Error) {
        stateListener?.didFailNomination(error: error)
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision)) {
            self.fee = fee
        } else {
            fee = nil
        }

        stateListener?.provideFee(viewModelState: self)
    }

    func didReceive(feeError: Error) {
        stateListener?.didReceiveError(error: feeError)
    }
}
