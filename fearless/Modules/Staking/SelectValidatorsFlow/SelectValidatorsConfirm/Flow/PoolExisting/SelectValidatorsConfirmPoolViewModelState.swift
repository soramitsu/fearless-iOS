import Foundation
import RobinHood
import BigInt
import SSFModels

// swiftlint:disable type_name
final class SelectValidatorsConfirmPoolExistingViewModelState: SelectValidatorsConfirmViewModelState {
    var balance: Decimal?

    var amount: Decimal? { 0.0 }
    var stateListener: SelectValidatorsConfirmModelStateListener?
    let poolId: UInt32
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let existingBonding: ExistingBonding
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let operationManager: OperationManagerProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    private(set) var confirmationModel: SelectValidatorsConfirmRelaychainModel?
    private(set) var priceData: PriceData?
    private(set) var fee: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var minNominatorBond: Decimal?
    private(set) var counterForNominators: UInt32?
    private(set) var maxNominatorsCount: UInt32?
    private(set) var stakingDuration: StakingDuration?
    private(set) var poolName: String?

    var payoutAccountAddress: String? {
        switch existingBonding.rewardDestination {
        case let .payout(account):
            return account
        default:
            return nil
        }
    }

    var walletAccountAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    init(
        poolId: UInt32,
        targets: [SelectedValidatorInfo],
        maxTargets: Int,
        existingBonding: ExistingBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        operationManager: OperationManagerProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol

    ) {
        self.poolId = poolId
        self.targets = targets
        self.maxTargets = maxTargets
        self.existingBonding = existingBonding
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.operationManager = operationManager
        self.dataValidatingFactory = dataValidatingFactory
        self.callFactory = callFactory
    }

    func setStateListener(_ stateListener: SelectValidatorsConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.maxNominatorsCountNotApplied(
                counterForNominators: counterForNominators,
                maxNominatorsCount: maxNominatorsCount,
                hasExistingNomination: false,
                locale: locale
            ),
            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                locale: locale
            )
        ]
    }

    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        let targets = targets
        let poolId = poolId

        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            let nominateCall = try strongSelf.callFactory.poolNominate(poolId: poolId, targets: targets)

            return try builder
                .adding(call: nominateCall)
        }

        return closure
    }

    private func createRewardDestinationOperation(
        for payoutAddress: String
    ) -> CompoundOperationWrapper<RewardDestination<DisplayAddress>> {
        let mapOperation: BaseOperation<RewardDestination<DisplayAddress>> = ClosureOperation { [weak self] in
            guard let strongSelf = self else {
                throw CommonError.internal
            }

            let displayAddress = DisplayAddress(
                address: strongSelf.wallet.fetch(
                    for: strongSelf.chainAsset.chain.accountRequest()
                )?.toAddress() ?? payoutAddress,
                username: strongSelf.wallet.name
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

        let mapOperation: BaseOperation<SelectValidatorsConfirmRelaychainModel> = ClosureOperation {
            let controller = currentBonding.controllerAccount
            let rewardDestination = try rewardDestWrapper.targetOperation.extractNoCancellableResultData()

            let controllerDisplayAddress = DisplayAddress(
                address: controller.toAddress() ?? "",
                username: controller.name
            )

            return SelectValidatorsConfirmRelaychainModel(
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

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                do {
                    strongSelf.confirmationModel = try mapOperation.extractNoCancellableResultData()

                    strongSelf.stateListener?.provideConfirmationState(viewModelState: strongSelf)
                } catch {
                    strongSelf.stateListener?.didReceiveError(error: error)
                }
            }
        }

        operationManager.enqueue(operations: dependencies + [mapOperation], in: .transient)
    }
}

extension SelectValidatorsConfirmPoolExistingViewModelState: SelectValidatorsConfirmPoolExistingStrategyOutput {
    func didSetup() {
        provideChangeTargetsConfirmationModel()
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
        if let feeValue = BigUInt(string: paymentInfo.fee),
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

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let availableValue = accountInfo?.data.stakingAvailable {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = 0.0
            }
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceive(error: Error) {
        stateListener?.didReceiveError(error: error)
    }

    func didReceive(poolName: String?) {
        self.poolName = poolName
        stateListener?.provideConfirmationState(viewModelState: self)
    }
}
